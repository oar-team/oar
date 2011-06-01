require "signal"

signal.signal("SIGTERM", function(n, i) print("signal handler", n, i); end);

signal.raise("SIGTERM");

signal.signal("SIGTERM", "ignore");

signal.raise("SIGTERM");

print "signal ignored";

signal.signal("SIGTERM", "default");

print "signal default action";

signal.raise("SIGTERM");
