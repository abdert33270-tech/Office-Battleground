use mlua::{Lua, Result};
fn main() -> Result<()> {
    let args: Vec<String> = std::env::args().collect();
    let lua = Lua::new();
    let src = std::fs::read_to_string(&args[1]).expect("read");
    let argv = lua.create_table()?;
    for (i, a) in args.iter().skip(2).enumerate() { argv.set(i + 1, a.clone())?; }
    lua.globals().set("ARGV", argv)?;
    // readfile / listdir helpers for the harness
    lua.globals().set("readfile", lua.create_function(|_, p: String| Ok(std::fs::read_to_string(p).ok()))?)?;
    lua.globals().set("listdir", lua.create_function(|lua, p: String| {
        let t = lua.create_table()?;
        if let Ok(rd) = std::fs::read_dir(p) { let mut v: Vec<String> = rd.filter_map(|e| e.ok()).map(|e| e.file_name().to_string_lossy().to_string()).collect(); v.sort(); for (i, n) in v.into_iter().enumerate() { t.set(i + 1, n)?; } }
        Ok(t)
    })?)?;
    lua.globals().set("isdir", lua.create_function(|_, p: String| Ok(std::path::Path::new(&p).is_dir()))?)?;
    lua.globals().set("loadsrc", lua.create_function(|lua, (code, name): (String, String)| {
        match lua.load(&code).set_name(name).into_function() { Ok(f) => Ok((Some(f), None)), Err(e) => Ok((None, Some(e.to_string()))) }
    })?)?;
    lua.sandbox(false)?;
    match lua.load(&src).set_name(args[1].clone()).exec() { Ok(_) => Ok(()), Err(e) => { eprintln!("{}", e); std::process::exit(1) } }
}
