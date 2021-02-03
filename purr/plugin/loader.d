module purr.plugin.loader;

import std.stdio;
import std.string;
import purr.plugin.plugins;
import purr.plugin.plugin;
import core.sys.posix.dlfcn;

void*[string] dlls;
string[] paths;

void linkLang(string name)
{
    name.loadLang.addPlugin;
}

Plugin loadLang(string name)
{
    immutable(char)* cname = void;
    if (name == "this")
    {
        cname = null;
    }
    else
    {
        cname = name.toStringz;
    }
    void* handle = dlopen(cname, RTLD_LAZY);
    if (handle is null)
    {
        throw new Exception(cast(string) ("cannot dlopen: " ~ name ~ " error: " ~ dlerror.fromStringz));
    }
    dlls[name] = handle;
    Plugin function() fplugin = cast(Plugin function()) dlsym(handle, "paka_get_library_plugin".toStringz);
    char* err = dlerror();
    if (err !is null)
    {
        throw new Exception(cast(string) ("dlsym error: " ~ err.fromStringz));
    }
    return fplugin();
}
