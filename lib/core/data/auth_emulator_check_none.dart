// Off the web, pointing Auth at the emulator can't silently fail.

bool authUsesEmulator() => true;

bool reloadForEmulatorOnce() => false;

void emulatorReached() {}
