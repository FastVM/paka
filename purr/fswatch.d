///
/// https://raw.githubusercontent.com/WebFreak001/FSWatch/master/source/fswatch.d
///
module fswatch;

import std.file;

import core.thread;

debug (FSWTestRun2) version = FSWForcePoll;

///
enum FileChangeEventType : ubyte
{
	/// Occurs when a file or folder is created.
	create,
	/// Occurs when a file or folder is modified.
	modify,
	/// Occurs when a file or folder is removed.
	remove,
	/// Occurs when a file or folder inside a folder is renamed.
	rename,
	/// Occurs when the watched path gets created.
	createSelf,
	/// Occurs when the watched path gets deleted.
	removeSelf
}

/// Structure containing information about filesystem events.
struct FileChangeEvent
{
	/// The type of this event.
	FileChangeEventType type;
	/// The path of the file of this event. Might not be set for createSelf and removeSelf.
	string path;
	/// The path the file got renamed to for a rename event.
	string newPath = null;
}

private ulong getUniqueHash(DirEntry entry)
{
	version (Windows)
		return entry.timeCreated.stdTime ^ cast(ulong) entry.attributes;
	else version (Posix)
		return entry.statBuf.st_ino | (cast(ulong) entry.statBuf.st_dev << 32UL);
	else
		return (entry.timeLastModified.stdTime ^ (
				cast(ulong) entry.attributes << 32UL) ^ entry.linkAttributes) * entry.size;
}

version (FSWForcePoll)
	version = FSWUsesPolling;
else
{
	version (Windows)
		version = FSWUsesWin32;
	else version (linux)
		version = FSWUsesINotify;
	else version = FSWUsesPolling;
}

/// An instance of a FileWatcher
/// Contains different implementations (win32 api, inotify and polling using the std.file methods)
/// Specify `version = FSWForcePoll;` to force using std.file (is slower and more resource intensive than the other implementations)
struct FileWatch
{
	// internal path variable which shouldn't be changed because it will not update inotify/poll/win32 structures uniformly.
	string _path;

	/// Path of the file set using the constructor
	const ref const(string) path() return @property @safe @nogc nothrow pure
	{
		return _path;
	}

	version (FSWUsesWin32)
	{
		/*
		 * The Windows version works by first creating an asynchronous path handle using CreateFile.
		 * The name may suggest this creates a new file on disk, but it actually gives
		 * a handle to basically anything I/O related. By using the flags FILE_FLAG_OVERLAPPED
		 * and FILE_FLAG_BACKUP_SEMANTICS it can be used in ReadDirectoryChangesW.
		 * 'Overlapped' here means asynchronous, it can also be done synchronously but that would
		 * mean getEvents() would wait until a directory change is registered.
		 * The asynchronous results can be received in a callback, but since FSWatch is polling
		 * based it polls the results using GetOverlappedResult. If messages are received,
		 * ReadDirectoryChangesW is called again.
		 * The function will not notify when the watched directory itself is removed, so
		 * if it doesn't exist anymore the handle is closed and set to null until it exists again.
		 */
		import core.sys.windows.windows : HANDLE, OVERLAPPED, CloseHandle,
			GetOverlappedResult, CreateFile, GetLastError,
			ReadDirectoryChangesW, FILE_NOTIFY_INFORMATION, FILE_ACTION_ADDED,
			FILE_ACTION_REMOVED, FILE_ACTION_MODIFIED,
			FILE_ACTION_RENAMED_NEW_NAME, FILE_ACTION_RENAMED_OLD_NAME,
			FILE_LIST_DIRECTORY, FILE_SHARE_WRITE, FILE_SHARE_READ,
			FILE_SHARE_DELETE, OPEN_EXISTING, FILE_FLAG_OVERLAPPED,
			FILE_FLAG_BACKUP_SEMANTICS, FILE_NOTIFY_CHANGE_FILE_NAME,
			FILE_NOTIFY_CHANGE_DIR_NAME, FILE_NOTIFY_CHANGE_LAST_WRITE,
			ERROR_IO_PENDING, ERROR_IO_INCOMPLETE, DWORD;
		import std.utf : toUTF8, toUTF16;
		import std.path : absolutePath;
		import std.conv : to;
		import std.datetime : SysTime;

		private HANDLE pathHandle; // Windows 'file' handle for ReadDirectoryChangesW
		private ubyte[1024 * 4] changeBuffer; // 4kb buffer for file changes
		private bool isDir, exists, recursive;
		private SysTime timeLastModified;
		private DWORD receivedBytes;
		private OVERLAPPED overlapObj;
		private bool queued; // Whether a directory changes watch is issued to Windows
		private string _absolutePath;

		/// Creates an instance using the Win32 API
		this(string path, bool recursive = false, bool treatDirAsFile = false)
		{
			_path = path;
			_absolutePath = absolutePath(path, getcwd);
			this.recursive = recursive;
			isDir = !treatDirAsFile;
			if (!isDir && recursive)
				throw new Exception("Can't recursively check on a file");
			getEvents(); // To create a path handle and start the watch queue
			// The result, likely containing just 'createSelf' or 'removeSelf', is discarded
			// This way, the first actual call to getEvents() returns actual events
		}

		~this()
		{
			CloseHandle(pathHandle);
		}

		private void startWatchQueue()
		{
			if (!ReadDirectoryChangesW(pathHandle, changeBuffer.ptr, changeBuffer.length, recursive,
					FILE_NOTIFY_CHANGE_FILE_NAME | FILE_NOTIFY_CHANGE_DIR_NAME | FILE_NOTIFY_CHANGE_LAST_WRITE,
					&receivedBytes, &overlapObj, null))
				throw new Exception("Failed to start directory watch queue. Error 0x" ~ GetLastError()
					.to!string(16));
			queued = true;
		}

		/// Implementation using Win32 API or polling for files
		FileChangeEvent[] getEvents()
		{
			const pathExists = _absolutePath.exists; // cached so it is not called twice
			if (isDir && (!pathExists || _absolutePath.isDir))
			{
				// ReadDirectoryChangesW does not report changes to the specified directory
				// itself, so 'removeself' is checked manually
				if (!pathExists)
				{
					if (pathHandle)
					{
						if (GetOverlappedResult(pathHandle, &overlapObj, &receivedBytes, false))
						{
						}
						queued = false;
						CloseHandle(pathHandle);
						pathHandle = null;
						return [FileChangeEvent(FileChangeEventType.removeSelf, ".")];
					}
					return [];
				}
				FileChangeEvent[] events;
				if (!pathHandle)
				{
					pathHandle = CreateFile((_absolutePath.toUTF16 ~ cast(wchar) 0).ptr, FILE_LIST_DIRECTORY,
							FILE_SHARE_WRITE | FILE_SHARE_READ | FILE_SHARE_DELETE,
							null, OPEN_EXISTING,
							FILE_FLAG_OVERLAPPED | FILE_FLAG_BACKUP_SEMANTICS, null);
					if (!pathHandle)
						throw new Exception("Error opening directory. Error code 0x" ~ GetLastError()
								.to!string(16));
					queued = false;
					events ~= FileChangeEvent(FileChangeEventType.createSelf, ".");
				}
				if (!queued)
				{
					startWatchQueue();
				}
				else
				{
					// ReadDirectoryW can give double modify messages, making the queue one event behind
					// This sequence is repeated as a fix for now, until the intricacy of WinAPI is figured out
					foreach(_; 0..2)
					{
						if (GetOverlappedResult(pathHandle, &overlapObj, &receivedBytes, false))
						{
							int i = 0;
							string fromFilename;
							while (true)
							{
								auto info = cast(FILE_NOTIFY_INFORMATION*)(changeBuffer.ptr + i);
								string fileName = (cast(wchar[])(
										cast(ubyte*) info.FileName)[0 .. info.FileNameLength])
									.toUTF8.idup;
								switch (info.Action)
								{
								case FILE_ACTION_ADDED:
									events ~= FileChangeEvent(FileChangeEventType.create, fileName);
									break;
								case FILE_ACTION_REMOVED:
									events ~= FileChangeEvent(FileChangeEventType.remove, fileName);
									break;
								case FILE_ACTION_MODIFIED:
									events ~= FileChangeEvent(FileChangeEventType.modify, fileName);
									break;
								case FILE_ACTION_RENAMED_OLD_NAME:
									fromFilename = fileName;
									break;
								case FILE_ACTION_RENAMED_NEW_NAME:
									events ~= FileChangeEvent(FileChangeEventType.rename,
											fromFilename, fileName);
									break;
								default:
									throw new Exception(
											"Unknown file notify action 0x" ~ info.Action.to!string(
											16));
								}
								i += info.NextEntryOffset;
								if (info.NextEntryOffset == 0)
									break;
							}
							queued = false;
							startWatchQueue();
						}
						else
						{
							if (GetLastError() != ERROR_IO_PENDING
								&& GetLastError() != ERROR_IO_INCOMPLETE)
								throw new Exception("Error receiving changes. Error code 0x"
									~ GetLastError().to!string(16));
							break;
						}
					}
				}
				return events;
			}
			else
			{
				const nowExists = _absolutePath.exists;
				if (nowExists && !exists)
				{
					exists = true;
					timeLastModified = _absolutePath.timeLastModified;
					return [FileChangeEvent(FileChangeEventType.createSelf, _absolutePath)];
				}
				else if (!nowExists && exists)
				{
					exists = false;
					return [FileChangeEvent(FileChangeEventType.removeSelf, _absolutePath)];
				}
				else if (nowExists)
				{
					const modTime = _absolutePath.timeLastModified;
					if (modTime != timeLastModified)
					{
						timeLastModified = modTime;
						return [FileChangeEvent(FileChangeEventType.modify, _absolutePath)];
					}
					else
						return [];
				}
				else
					return [];
			}
		}
	}
	else version (FSWUsesINotify)
	{
		import core.sys.linux.sys.inotify : inotify_rm_watch, inotify_init1,
			inotify_add_watch, inotify_event, IN_CREATE, IN_DELETE,
			IN_DELETE_SELF, IN_MODIFY, IN_MOVE_SELF, IN_MOVED_FROM, IN_MOVED_TO,
			IN_NONBLOCK, IN_ATTRIB, IN_EXCL_UNLINK;
		import core.sys.linux.unistd : close, read;
		import core.sys.linux.fcntl : fcntl, F_SETFD, FD_CLOEXEC, stat, stat_t, S_ISDIR;
		import core.sys.linux.errno : errno;
		import core.sys.posix.poll : pollfd, poll, POLLIN;
		import core.stdc.errno : ENOENT;
		import std.algorithm : countUntil;
		import std.string : toStringz, stripRight;
		import std.conv : to;
		import std.path : relativePath, buildPath;

		private int fd;
		private bool recursive;
		private ubyte[1024 * 4] eventBuffer; // 4kb buffer for events
		private pollfd pfd;
		private struct FDInfo { int wd; bool watched; string path; }
		private FDInfo[] directoryMap; // map every watch descriptor to a directory

		/// Creates an instance using the linux inotify API
		this(string path, bool recursive = false, bool ignored = false)
		{
			_path = path;
			this.recursive = recursive;
			getEvents();
		}

		~this()
		{
			if (fd)
			{
				foreach (ref fdinfo; directoryMap)
					if (fdinfo.watched)
						inotify_rm_watch(fd, fdinfo.wd);
				close(fd);
			}
		}

		private void addWatch(string path)
		{
			auto wd = inotify_add_watch(fd, path.toStringz,
					IN_CREATE | IN_DELETE | IN_DELETE_SELF | IN_MODIFY | IN_MOVE_SELF
					| IN_MOVED_FROM | IN_MOVED_TO | IN_ATTRIB | IN_EXCL_UNLINK);
			assert(wd != -1,
					"inotify_add_watch returned invalid watch descriptor. Error code "
					~ errno.to!string);
			assert(fcntl(fd, F_SETFD, FD_CLOEXEC) != -1,
					"Could not set FD_CLOEXEC bit. Error code " ~ errno.to!string);
			directoryMap ~= FDInfo(wd, true, path);
		}

		/// Implementation using inotify
		FileChangeEvent[] getEvents()
		{
			FileChangeEvent[] events;
			if (!fd && path.exists)
			{
				fd = inotify_init1(IN_NONBLOCK);
				assert(fd != -1,
						"inotify_init1 returned invalid file descriptor. Error code "
						~ errno.to!string);
				addWatch(path);
				events ~= FileChangeEvent(FileChangeEventType.createSelf, path);

				if (recursive)
					foreach(string subPath; dirEntries(path, SpanMode.depth))
					{
						addWatch(subPath);
						events ~= FileChangeEvent(FileChangeEventType.createSelf, subPath);
					}
			}
			if (!fd)
				return events;
			pfd.fd = fd;
			pfd.events = POLLIN;
			const code = poll(&pfd, 1, 0);
			if (code < 0)
				throw new Exception("Failed to poll events. Error code " ~ errno.to!string);
			else if (code == 0)
				return events;
			else
			{
				const receivedBytes = read(fd, eventBuffer.ptr, eventBuffer.length);
				int i = 0;
				string fromFilename;
				uint cookie;
				while (true)
				{
					auto info = cast(inotify_event*)(eventBuffer.ptr + i);
					string fileName = info.name.ptr[0..info.len].stripRight("\0").idup;
					auto mapIndex = directoryMap.countUntil!(a => a.wd == info.wd);
					string absoluteFileName = buildPath(directoryMap[mapIndex].path, fileName);
					string relativeFilename = relativePath("/" ~ absoluteFileName, "/" ~ path);
					if (cookie && (info.mask & IN_MOVED_TO) == 0)
					{
						events ~= FileChangeEvent(FileChangeEventType.remove, fromFilename);
						fromFilename.length = 0;
						cookie = 0;
					}
					if ((info.mask & IN_CREATE) != 0)
					{
						// If a dir/file is created and deleted immediately then
						// isDir will throw FileException(ENOENT)
						if (recursive)
						{
							stat_t dirCheck;
							if (stat(absoluteFileName.toStringz, &dirCheck) == 0)
							{
								if (S_ISDIR(dirCheck.st_mode))
									addWatch(absoluteFileName);
							}
							else
							{
								const err = errno;
								if (err != ENOENT)
									throw new FileException(absoluteFileName, err);
							}
						}

						events ~= FileChangeEvent(FileChangeEventType.create, relativeFilename);
					}
					if ((info.mask & IN_DELETE) != 0)
						events ~= FileChangeEvent(FileChangeEventType.remove, relativeFilename);
					if ((info.mask & IN_MODIFY) != 0 || (info.mask & IN_ATTRIB) != 0)
						events ~= FileChangeEvent(FileChangeEventType.modify, relativeFilename);
					if ((info.mask & IN_MOVED_FROM) != 0)
					{
						fromFilename = fileName;
						cookie = info.cookie;
					}
					if ((info.mask & IN_MOVED_TO) != 0)
					{
						if (info.cookie == cookie)
						{
							events ~= FileChangeEvent(FileChangeEventType.rename,
									fromFilename, relativeFilename);
						}
						else
							events ~= FileChangeEvent(FileChangeEventType.create, relativeFilename);
						cookie = 0;
					}
					if ((info.mask & IN_DELETE_SELF) != 0 || (info.mask & IN_MOVE_SELF) != 0)
					{
						if (fd)
						{
							inotify_rm_watch(fd, info.wd);
							directoryMap[mapIndex].watched = false;
						}
						if (directoryMap[mapIndex].path == path)
							events ~= FileChangeEvent(FileChangeEventType.removeSelf, ".");
					}
					i += inotify_event.sizeof + info.len;
					if (i >= receivedBytes)
						break;
				}
				if (cookie)
				{
					events ~= FileChangeEvent(FileChangeEventType.remove, fromFilename);
					fromFilename.length = 0;
					cookie = 0;
				}
			}
			return events;
		}
	}
	else version (FSWUsesPolling)
	{
		import std.datetime : SysTime;
		import std.algorithm : countUntil, remove;
		import std.path : relativePath, absolutePath, baseName;

		private struct FileEntryCache
		{
			SysTime lastModification;
			const string name;
			bool isDirty;
			ulong uniqueHash;
		}

		private FileEntryCache[] cache;
		private bool isDir, recursive, exists;
		private SysTime timeLastModified;
		private string cwd;

		/// Generic fallback implementation using std.file.dirEntries
		this(string path, bool recursive = false, bool treatDirAsFile = false)
		{
			_path = path;
			cwd = getcwd;
			this.recursive = recursive;
			isDir = !treatDirAsFile;
			if (!isDir && recursive)
				throw new Exception("Can't recursively check on a file");
			getEvents();
		}

		/// Generic polling implementation
		FileChangeEvent[] getEvents()
		{
			const nowExists = path.exists;
			if (isDir && (!nowExists || path.isDir))
			{
				FileChangeEvent[] events;
				if (nowExists && !exists)
				{
					exists = true;
					events ~= FileChangeEvent(FileChangeEventType.createSelf, ".");
				}
				if (!nowExists && exists)
				{
					exists = false;
					return [FileChangeEvent(FileChangeEventType.removeSelf, ".")];
				}
				if (!nowExists)
					return [];
				foreach (ref e; cache)
					e.isDirty = true;
				DirEntry[] created;
				foreach (file; dirEntries(path, recursive ? SpanMode.breadth : SpanMode.shallow))
				{
					auto newCache = FileEntryCache(file.timeLastModified,
							file.name, false, file.getUniqueHash);
					bool found = false;
					foreach (ref cacheEntry; cache)
					{
						if (cacheEntry.name == newCache.name)
						{
							if (cacheEntry.lastModification != newCache.lastModification)
							{
								cacheEntry.lastModification = newCache.lastModification;
								events ~= FileChangeEvent(FileChangeEventType.modify,
										relativePath(file.name.absolutePath(cwd),
											path.absolutePath(cwd)));
							}
							cacheEntry.isDirty = false;
							found = true;
							break;
						}
					}
					if (!found)
					{
						cache ~= newCache;
						created ~= file;
					}
				}
				foreach_reverse (i, ref e; cache)
				{
					if (e.isDirty)
					{
						auto idx = created.countUntil!((a, b) => a.getUniqueHash == b.uniqueHash)(e);
						if (idx != -1)
						{
							events ~= FileChangeEvent(FileChangeEventType.rename,
									relativePath(e.name.absolutePath(cwd),
										path.absolutePath(cwd)), relativePath(created[idx].name.absolutePath(cwd),
										path.absolutePath(cwd)));
							created = created.remove(idx);
						}
						else
						{
							events ~= FileChangeEvent(FileChangeEventType.remove,
									relativePath(e.name.absolutePath(cwd), path.absolutePath(cwd)));
						}
						cache = cache.remove(i);
					}
				}
				foreach (ref e; created)
				{
					events ~= FileChangeEvent(FileChangeEventType.create,
							relativePath(e.name.absolutePath(cwd), path.absolutePath(cwd)));
				}
				if (events.length && events[0].type == FileChangeEventType.createSelf)
					return [events[0]];
				return events;
			}
			else
			{
				if (nowExists && !exists)
				{
					exists = true;
					timeLastModified = path.timeLastModified;
					return [FileChangeEvent(FileChangeEventType.createSelf, ".")];
				}
				else if (!nowExists && exists)
				{
					exists = false;
					return [FileChangeEvent(FileChangeEventType.removeSelf, ".")];
				}
				else if (nowExists)
				{
					const modTime = path.timeLastModified;
					if (modTime != timeLastModified)
					{
						timeLastModified = modTime;
						return [FileChangeEvent(FileChangeEventType.modify, path.baseName)];
					}
					else
						return [];
				}
				else
					return [];
			}
		}
	}
	else
		static assert(0, "No filesystem watching method?! Try setting version = FSWForcePoll;");
}

///
unittest
{
	import core.thread;

	FileChangeEvent waitForEvent(ref FileWatch watcher)
	{
		FileChangeEvent[] ret;
		while ((ret = watcher.getEvents()).length == 0)
		{
			Thread.sleep(1.msecs);
		}
		return ret[0];
	}

	if (exists("test"))
		rmdirRecurse("test");
	scope (exit)
	{
		if (exists("test"))
			rmdirRecurse("test");
	}

	auto watcher = FileWatch("test", true);
	assert(watcher.path == "test");
	mkdir("test");
	auto ev = waitForEvent(watcher);
	assert(ev.type == FileChangeEventType.createSelf);
	write("test/a.txt", "abc");
	ev = waitForEvent(watcher);
	assert(ev.type == FileChangeEventType.create);
	assert(ev.path == "a.txt");
	Thread.sleep(2000.msecs); // for polling variant
	append("test/a.txt", "def");
	ev = waitForEvent(watcher);
	assert(ev.type == FileChangeEventType.modify);
	assert(ev.path == "a.txt");
	rename("test/a.txt", "test/b.txt");
	ev = waitForEvent(watcher);
	assert(ev.type == FileChangeEventType.rename);
	assert(ev.path == "a.txt");
	assert(ev.newPath == "b.txt");
	remove("test/b.txt");
	ev = waitForEvent(watcher);
	assert(ev.type == FileChangeEventType.remove);
	assert(ev.path == "b.txt");
	rmdirRecurse("test");
	ev = waitForEvent(watcher);
	assert(ev.type == FileChangeEventType.removeSelf);
}

version (linux) unittest
{
	import core.thread;

	FileChangeEvent waitForEvent(ref FileWatch watcher, Duration timeout = 2.seconds)
	{
		FileChangeEvent[] ret;
		Duration elapsed;
		while ((ret = watcher.getEvents()).length == 0)
		{
			Thread.sleep(1.msecs);
			elapsed += 1.msecs;
			if (elapsed >= timeout)
				throw new Exception("timeout");
		}
		return ret[0];
	}

	if (exists("test2"))
		rmdirRecurse("test2");
	if (exists("test3"))
		rmdirRecurse("test3");
	scope (exit)
	{
		if (exists("test2"))
			rmdirRecurse("test2");
		if (exists("test3"))
			rmdirRecurse("test3");
	}

	auto watcher = FileWatch("test2", true);
	mkdir("test2");
	auto ev = waitForEvent(watcher);
	assert(ev.type == FileChangeEventType.createSelf);
	write("test2/a.txt", "abc");
	ev = waitForEvent(watcher);
	assert(ev.type == FileChangeEventType.create);
	assert(ev.path == "a.txt");
	rename("test2/a.txt", "./testfile-a.txt");
	ev = waitForEvent(watcher);
	assert(ev.type == FileChangeEventType.remove);
	assert(ev.path == "a.txt");
	rename("./testfile-a.txt", "test2/b.txt");
	ev = waitForEvent(watcher);
	assert(ev.type == FileChangeEventType.create);
	assert(ev.path == "b.txt");
	remove("test2/b.txt");
	ev = waitForEvent(watcher);
	assert(ev.type == FileChangeEventType.remove);
	assert(ev.path == "b.txt");

	mkdir("test2/mydir");
	rmdir("test2/mydir");
	try
	{
		ev = waitForEvent(watcher);
		// waitForEvent only returns first event (just a test method anyway) because on windows or unprecise platforms events can be spawned multiple times
		// or could be never fired in case of slow polling mechanism
		assert(ev.type == FileChangeEventType.create);
		assert(ev.path == "mydir");
	}
	catch (Exception e)
	{
		if (e.msg != "timeout")
			throw e;
	}

	version (FSWUsesINotify)
	{
		// test for creation, modification, removal of subdirectory
		mkdir("test2/subdir");
		ev = waitForEvent(watcher);
		assert(ev.type == FileChangeEventType.create);
		assert(ev.path == "subdir");
		write("test2/subdir/c.txt", "abc");
		ev = waitForEvent(watcher);
		assert(ev.type == FileChangeEventType.create);
		assert(ev.path == "subdir/c.txt");
		write("test2/subdir/c.txt", "\nabc");
		ev = waitForEvent(watcher);
		assert(ev.type == FileChangeEventType.modify);
		assert(ev.path == "subdir/c.txt");
		rmdirRecurse("test2/subdir");
		auto events = watcher.getEvents();
		assert(events[0].type == FileChangeEventType.remove);
		assert(events[0].path == "subdir/c.txt");
		assert(events[1].type == FileChangeEventType.remove);
		assert(events[1].path == "subdir");
	}
	// removal of watched folder
	rmdirRecurse("test2");
	ev = waitForEvent(watcher);
	assert(ev.type == FileChangeEventType.removeSelf);
	assert(ev.path == ".");

	version (FSWUsesINotify)
	{
		// test for a subdirectory already present
		// both when recursive = true and recursive = false
		foreach (recursive; [true, false])
		{
			mkdir("test3");
			mkdir("test3/a");
			mkdir("test3/a/b");
			watcher = FileWatch("test3", recursive);
			write("test3/a/b/c.txt", "abc");
			if (recursive)
			{
				ev = waitForEvent(watcher);
				assert(ev.type == FileChangeEventType.create);
				assert(ev.path == "a/b/c.txt");
			}
			if (!recursive)
			{
				// creation of subdirectory and file within
				// test that addWatch doesn't get called
				mkdir("test3/d");
				write("test3/d/e.txt", "abc");
				auto revents = watcher.getEvents();
				assert(revents.length == 1);
				assert(revents[0].type == FileChangeEventType.create);
				assert(revents[0].path == "d");
				rmdirRecurse("test3/d");
				revents = watcher.getEvents();
				assert(revents.length == 1);
				assert(revents[0].type == FileChangeEventType.remove);
				assert(revents[0].path == "d");
			}
			rmdirRecurse("test3");
			events = watcher.getEvents();
			if (recursive)
			{
				assert(events.length == 4);
				assert(events[0].type == FileChangeEventType.remove);
				assert(events[0].path == "a/b/c.txt");
				assert(events[1].type == FileChangeEventType.remove);
				assert(events[1].path == "a/b");
				assert(events[2].type == FileChangeEventType.remove);
				assert(events[2].path == "a");
				assert(events[3].type == FileChangeEventType.removeSelf);
				assert(events[3].path == ".");
			}
			else
			{
				assert(events.length == 2);
				assert(events[0].type == FileChangeEventType.remove);
				assert(events[0].path == "a");
				assert(events[1].type == FileChangeEventType.removeSelf);
				assert(events[1].path == ".");
			}
		}
	}
}