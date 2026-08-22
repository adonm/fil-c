local parse = require("../sarcasm/arm64_parse")
local lift = require("../sarcasm/lift")
local emit = require("../sarcasm/arm64_render")
local fs = require("@lute/fs")

-- Extract just the function body between "hash:" label and ".cfi_endproc"/next.
local function bodyOf(file)
    local stmts = parse.parseString(fs.read(fs.open("tests/"..file,"r")))
    local body, inFunc = {}, false
    for _, st in stmts do
        if st.kind=="label" and st.name=="hash" then inFunc=true end
        if inFunc then
            if st.kind=="directive" and st.name==".size" then break end
            table.insert(body, st)
        end
    end
    return body
end

for _, file in {"test-spasm.s","test2-spasm.s","test3-spasm.s","test3-spasm0.s"} do
    print("==== "..file.." ====")
    local body = bodyOf(file)
    local lf = lift.liftFunction(body)
    local ntemps = 0; for _ in lf.temps do ntemps+=1 end
    print("temps:", ntemps)
    -- identity coloring: temp -> its original reg num
    local function colorOf(t) return lf.temps[t] and lf.temps[t].reg end
    local mismatches = 0
    for _, node in lf.nodes do
        if node.kind=="insn" then
            local orig = node.stmt.raw
            local rendered = emit.renderInsn(node, colorOf)
            -- normalize whitespace/# for comparison
            local function norm(s) s=string.gsub(s,"%s+"," "); s=string.gsub(s,"#",""); s=string.gsub(s,"^%s*(.-)%s*$","%1"); return string.lower(s) end
            if norm(orig) ~= norm(rendered) then
                mismatches += 1
                print(string.format("  MISMATCH:\n    orig: %s\n    got:  %s", orig, rendered))
            end
        end
    end
    print("mismatches:", mismatches)
end
