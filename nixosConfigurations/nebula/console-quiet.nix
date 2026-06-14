{
  # Keep harmless kernel chatter off the console / greeter.
  #
  # On this AMD board the i2c_piix4 SMBus ports (i2c-1 / i2c-2, the RAM-SPD &
  # sensors bus — NOT the NVIDIA monitor DDC buses) emit err-priority probe
  # NAKs a few seconds into boot:
  #     kernel: i2c i2c-1: Failed reset at end of transaction (01)
  #     kernel: i2c i2c-1: Failed! (01)
  # These are a well-known, benign AMD SMBus quirk (a device on the bus doesn't
  # ACK a probe). Because they're KERN_ERR they render on the VT right as the ly
  # greeter comes up, reading like a boot failure when nothing is wrong.
  #
  # consoleLogLevel sets the kernel console_loglevel: only messages strictly
  # more severe than this value print to the console. Default is 4, which lets
  # ERR(3) through. Setting it to 3 prints only crit/alert/emerg (0–2) on the
  # console while journald still records EVERYTHING (`journalctl -k` is
  # unaffected) — so real diagnostics are never lost, they just stop flashing on
  # the login screen.
  boot.consoleLogLevel = 3;
}
