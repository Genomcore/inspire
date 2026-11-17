// plugin/scripts/visor-loopback.mjs — preloaded by visor.sh (`node --import`) into the
// Quartz server on the host's Node. Quartz has no host option and binds its HTTP and
// live-reload servers on every interface; a listen() that names no host binds 127.0.0.1.
// The live-reload server (ws) passes its host as null when none is set.

import net from "node:net"

const listen = net.Server.prototype.listen
net.Server.prototype.listen = function (...args) {
  const [port, host] = args
  if (typeof port === "number" || (typeof port === "string" && /^\d+$/.test(port))) {
    if (host == null) args[1] = "127.0.0.1"
    else if (typeof host === "function") args.splice(1, 0, "127.0.0.1")
  } else if (port && typeof port === "object" && port.path == null && port.host == null) {
    args[0] = { ...port, host: "127.0.0.1" }
  }
  return listen.apply(this, args)
}
