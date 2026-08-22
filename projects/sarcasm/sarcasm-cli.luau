local sarcasm = require("./sarcasm/sarcasm")
local process = require("@lute/process")
process.exit(sarcasm.main(process.args))
