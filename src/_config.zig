const build = @import("builtin");
pub const CONFIG = if (!build.is_test) @import("config") else struct { SDL_USER_MAIN: bool, SDL_USER_CALLBACKS: bool, NO_SDL: bool }{
    .SDL_USER_MAIN = true,
    .SDL_USER_CALLBACKS = true,
    .NO_SDL = false,
};
