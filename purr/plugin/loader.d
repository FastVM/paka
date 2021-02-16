module purr.plugin.loader;

version (linux)
{
    import purr.io;
    import std.string;
    import purr.plugin.plugins;
    import purr.plugin.plugin;
    import core.sys.posix.dlfcn;

    void*[string] dlls;

    void linkLang(string name)
    {
        name.loadLang.addPlugin;
    }

    Plugin loadLang(string name)
    {
        const(char)* cname;
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
            throw new Exception(cast(string)(
                    "cannot dlopen: " ~ name ~ " error: " ~ dlerror.fromStringz));
        }
        dlls[name] = handle;
        Plugin function() fplugin = cast(Plugin function()) dlsym(handle,
                "purr_get_library_plugin".toStringz);
        char* err = dlerror();
        if (err !is null)
        {
            throw new Exception(cast(string)("dlsym error: " ~ err.fromStringz));
        }
        return fplugin();
    }
}
else version(Windows)
{
    import purr.io;
    import std.string;
    import purr.plugin.plugins;
    import purr.plugin.plugin;

    extern(C) Plugin purr_get_library_plugin();

    void linkLang(string name)
    {
        name.loadLang.addPlugin;
    }

    Plugin loadLang(string name)
    {
        if (name != "this")
        {
            throw new Exception("i dont know how to get dlls working on windows");
        }
        return purr_get_library_plugin;
    }
}