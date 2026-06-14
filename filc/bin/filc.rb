# frozen_string_literal: true
# filc.rb — invoked by filc/bin/filc wrapper

# filc — The Fil-C developer CLI
# One command to rule them all: build, test, compile, and debug Fil-C programs.
#
# Usage: filc COMMAND [OPTIONS]
#   filc doctor          Check that the development environment is ready
#   filc build           Build Fil-C (compiler + runtime + libc)
#   filc build --component=NAME  Build a specific component
#   filc compile FILE... Compile C/C++ files with the Fil-C compiler
#   filc test             Run the test suite
#   filc test --filter=REGEX  Run matching tests
#   filc run FILE...      Compile and run a Fil-C program
#   filc info             Print project build info
#   filc shell            Start a shell with Fil-C tools on PATH
#   filc clean            Clean build artifacts

require "pathname"
require "shellwords"
require "etc"
require "fileutils"
require "optparse"
require "yaml"

TOML_AVAILABLE = begin
  require "toml-rb"
  true
rescue LoadError
  false
end

module FilC
  VERSION = "0.1.0"

  class Error < StandardError; end

  # Resolve paths relative to the repository root
  module Paths
    def self.root
      @root ||= begin
        # Walk up from __FILE__ to find the repo root (where .mise.toml or build_base.sh lives)
        dir = Pathname.new(__dir__)
        loop do
          if (dir / ".mise.toml").exist? || (dir / "build_base.sh").exist?
            break dir
          end
          parent = dir.parent
          raise Error, "Cannot find Fil-C repository root from #{__dir__}" if parent == dir
          dir = parent
        end
      end
    end

    def self.build_dir = root / "build"
    def self.pizfix = root / "pizfix"
    def self.clang = build_dir / "bin" / "clang"
    def self.clangxx = build_dir / "bin" / "clang++"
    def self.filcc = build_dir / "bin" / "filcc"
    def self.test_runner = root / "filc" / "run-tests"
    def self.test_dir = root / "filc" / "tests"
    def self.test_output = root / "filc" / "test-output"

    def self.ensure_root!
      raise Error, "Not in a Fil-C repository (missing .mise.toml or build_base.sh from #{root})" unless root
    end
  end

  # Environment checks
  module Doctor
    CHECKS = {
      gcc:          { cmd: "gcc",              msg: "Host C compiler (build-essential)", required: true },
      gxx:          { cmd: "g++",              msg: "Host C++ compiler", required: true },
      cmake:        { cmd: "cmake",            msg: "CMake build system", required: true },
      ninja:        { cmd: "ninja",            msg: "Ninja build tool", required: true },
      ruby:         { cmd: "ruby",             msg: "Ruby (test runner)", required: true },
      patchelf:     { cmd: "patchelf",         msg: "ELF patcher", required: true },
      git:          { cmd: "git",              msg: "Git version control", required: true },
      make:         { cmd: "make",             msg: "GNU Make", required: true },
      pkg_config:   { cmd: "pkg-config",       msg: "pkg-config", required: false },
      autoconf:     { cmd: "autoconf",         msg: "Autoconf (ported projects)", required: false },
      automake:     { cmd: "automake",         msg: "Automake (ported projects)", required: false },
      libtool:      { cmd: "libtool",          msg: "Libtool (ported projects)", required: false },
      bison:        { cmd: "bison",            msg: "Bison parser generator", required: false },
      flex:         { cmd: "flex",             msg: "Flex lexer generator", required: false },
      makeinfo:     { cmd: "makeinfo",         msg: "Texinfo/makeinfo", required: false },
      gettext:      { cmd: "gettext",          msg: "Gettext i18n", required: false },
      kernel_hdrs:  { check: :kernel_headers,  msg: "Kernel headers (/usr/include/linux)", required: true },
      mise_config:  { check: :mise_config,     msg: "mise config (.mise.toml)", required: true },
    }

    def self.run
      puts "filc doctor — checking development environment"
      puts "  Repository root: #{Paths.root}"
      puts

      all_ok = true
      CHECKS.each do |name, spec|
        ok = case spec[:check]
        when :kernel_headers
          File.directory?("/usr/include/linux") && File.directory?("/usr/include/asm")
        when :mise_config
          (Paths.root / ".mise.toml").exist?
        else
          system("command -v #{spec[:cmd]} > /dev/null 2>&1")
        end

        status = ok ? "✓" : (spec[:required] ? "✗" : "○")
        all_ok = false if !ok && spec[:required]

        printf "  %s %-20s %s", status, name, spec[:msg]
        if spec[:cmd] && ok
          path = `command -v #{spec[:cmd]}`.strip
          print " → #{path}"
        end
        puts
      end

      puts
      if all_ok
        puts "✓ Environment ready. Run 'filc build' to build Fil-C."
      else
        puts "✗ Required tools missing. Run 'mise install && mise run install-deps' first."
      end
      all_ok
    end
  end

  # Build Fil-C from source
  module Builder
    COMPONENTS = {
      "compiler-rt"  => { script: "build_compiler_rt.sh",  desc: "Compiler runtime (crtbegin, crtend, libyolort)" },
      "yolounwind"   => { script: "build_yolounwind.sh",   desc: "Yolo unwinder" },
      "llvm"         => { script: "configure_llvm.sh",     desc: "LLVM/Clang configuration (cmake)" },
      "clang"        => { script: "build_clang.sh",         desc: "Clang compiler (ninja + fix)" },
      "os-include"   => { script: "build_os_include.sh",   desc: "OS include symlinks" },
      "yolomusl"     => { script: "build_yolomusl.sh",     desc: "Yolo musl libc" },
      "runtime"      => { script: "build_runtime.sh",      desc: "Fil-C runtime (libpas)" },
      "usermusl"     => { script: "build_usermusl.sh",     desc: "User musl libc" },
      "cxx"          => { script: "build_cxx.sh",          desc: "C++ standard library (libc++/libc++abi)" },
    }.freeze

    def self.run(component: nil)
      Paths.ensure_root!

      if component
        comp = COMPONENTS[component]
        raise Error, "Unknown component: #{component}. Available: #{COMPONENTS.keys.join(', ')}" unless comp
        run_script(comp[:script], "Building #{component}: #{comp[:desc]}")
        setup_compile_commands if component == "llvm" || component == "clang"
      elsif clang_built?
        # Rebuild only what changed
        puts "filc: Clang already built. Rebuilding runtime and libc..."
        run_script("build_runtime.sh", "Rebuilding runtime")
        run_script("build_usermusl.sh", "Rebuilding user musl")
        run_script("build_cxx.sh", "Rebuilding C++ stdlib")
        setup_compile_commands
      else
        puts "filc: Full build starting..."
        puts "  This builds: compiler-rt → yolo-unwind → LLVM/clang → os-include"
        puts "               → yolo-musl → runtime → user-musl → C++ stdlib"
        puts

        run_full_build
        setup_compile_commands
      end
    end

    def self.list_components
      puts "Build components:"
      COMPONENTS.each do |name, comp|
        printf "  %-15s %s\n", name, comp[:desc]
      end
    end

    private

    def self.clang_built?
      Paths.clang.exist? && (Paths.build_dir / "bin" / "filcc").exist?
    end

    def self.run_full_build
      script = Paths.root / "build_all_fast.sh"
      raise Error, "build_all_fast.sh not found" unless script.exist?
      exec_script(script)
    end

    def self.run_script(name, header)
      script = Paths.root / name
      raise Error, "Build script not found: #{name}" unless script.exist?
      puts header
      puts "  Running: #{name}"
      Dir.chdir(Paths.root) do
        system("bash", script.to_s) || raise(Error, "Build step failed: #{name}")
      end
    end

    def self.exec_script(script)
      Dir.chdir(Paths.root) do
        exec("bash", script.to_s)
      end
    end

    def self.setup_compile_commands
      cc_json = Paths.build_dir / "compile_commands.json"
      symlink = Paths.root / "compile_commands.json"
      if cc_json.exist?
        FileUtils.ln_sf(cc_json.to_s, symlink.to_s)
        puts "  Linked compile_commands.json → editors (clangd, VS Code) can now provide autocomplete"
      end
    end
  end

  # Compile user code with Fil-C
  module Compiler
    def self.compile(files, output: nil, opt: "-O", debug: true, std: nil)
      Paths.ensure_root!

      unless Paths.clang.exist?
        raise Error, "Fil-C compiler not found at #{Paths.clang}. Run 'filc build' first."
      end

      flags = [opt]
      flags << "-g" if debug
      flags << "-std=#{std}" if std

      output ||= "a.out"
      flags << "-o" << output

      compiler = determine_compiler(files)
      cmd = [compiler.to_s] + flags + files

      puts "filc: #{cmd.shelljoin}"
      Dir.chdir(Paths.root) do
        system(*cmd) || raise(Error, "Compilation failed")
      end
      puts "  → #{output}"
      output
    end

    private

    def self.determine_compiler(files)
      exts = files.map { |f| File.extname(f).downcase }.uniq
      if exts.any? { |e| %w[.cpp .cc .cxx .c++].include?(e) }
        Paths.clangxx
      else
        Paths.clang
      end
    end
  end

  # Run a Fil-C program (compile + execute)
  module Runner
    def self.run(files, args: [], **compile_opts)
      output = Compiler.compile(files, **compile_opts)
      binary = Pathname.new(output).absolute? ? output : "#{Paths.root}/#{output}"

      lib_path = "#{Paths.pizfix}/lib_test:#{Paths.pizfix}/lib"
      env = { "LD_LIBRARY_PATH" => lib_path }

      puts "filc: running #{binary}..."
      Dir.chdir(Paths.root) do
        cmd = [binary.to_s] + args
        system(env, *cmd) || raise(Error, "Program exited with error")
      end
    end
  end

  # Test runner
  module Tester
    def self.run(filter: nil, verbose: false, no_run: false)
      Paths.ensure_root!

      args = []
      args << "--filter" << filter if filter
      args << "--verbose" if verbose
      args << "--no-run" if no_run

      puts "filc: running tests..."
      puts "  Runner: #{Paths.test_runner}"
      puts "  Tests:  #{Paths.test_dir} (#{test_count} test directories)"

      Dir.chdir(Paths.root) do
        system("ruby", Paths.test_runner.to_s, *args)
      end
    end

    def self.test_count
      Dir.glob("#{Paths.test_dir}/*/manifest").count
    end
  end

  # Project info
  module Info
    def self.print
      Paths.ensure_root!

      puts "Fil-C development environment"
      puts
      puts "  Repository:     #{Paths.root}"
      puts "  Build dir:      #{Paths.build_dir}"
      puts "  Pizfix (stage): #{Paths.pizfix}"
      puts "  Compiler:       #{Paths.clang} (#{Paths.clang.exist? ? 'built' : 'not built'})"
      puts "  Test runner:    #{Paths.test_runner}"
      puts "  Tests:          #{Dir.glob("#{Paths.test_dir}/*/manifest").count} test directories"
      puts "  Architecture:   x86_64"
      puts "  Libc:           musl (default) / glibc 2.40"
      puts
      puts "Commands:"
      printf "  %-25s %s\n", "filc doctor", "Check environment"
      printf "  %-25s %s\n", "filc build", "Build Fil-C (full or incremental)"
      printf "  %-25s %s\n", "filc build --component=X", "Build one component"
      printf "  %-25s %s\n", "filc compile foo.c", "Compile with Fil-C"
      printf "  %-25s %s\n", "filc run foo.c", "Compile and run"
      printf "  %-25s %s\n", "filc test", "Run test suite"
      printf "  %-25s %s\n", "filc info", "This output"
      printf "  %-25s %s\n", "filc shell", "Shell with Fil-C tools on PATH"
      printf "  %-25s %s\n", "filc clean", "Clean build artifacts"
      puts
      puts "Environment variables:"
      puts "  FUGC_STW=1               Force stop-the-world GC"
      puts "  FUGC_SCRIBBLE=1          Scribble freed memory"
      puts "  FUGC_VERIFY=1            Verify heap integrity"
      puts "  FUGC_RAGE_MODE=1         Aggressive GC triggering"
      puts "  FUGC_MIN_THRESHOLD=0     Zero GC threshold (stress testing)"
      puts "  FILC_EXIT_ON_PANIC=1     Exit on safety violation"
      puts "  FILC_DUMP_SETUP=1        Dump environment at startup"
    end
  end

  # Shell with Fil-C tools
  module Shell
    def self.start
      Paths.ensure_root!

      shell = ENV["SHELL"] || "/bin/bash"
      bin_path = (Paths.build_dir / "bin").to_s
      lib_path = "#{Paths.pizfix}/lib_test:#{Paths.pizfix}/lib"

      new_path = "#{bin_path}:#{ENV['PATH']}"
      new_ld = lib_path

      puts "filc: starting shell with Fil-C toolchain..."
      puts "  PATH=#{new_path}"
      puts "  LD_LIBRARY_PATH=#{new_ld}"
      puts "  Try: clang --version, filcc foo.c"
      puts

      env = ENV.to_h.merge(
        "PATH" => new_path,
        "LD_LIBRARY_PATH" => new_ld,
        "FILC_SHELL" => "1"
      )

      Dir.chdir(Paths.root) do
        exec(env, shell)
      end
    end
  end

  # Clean build artifacts
  module Cleaner
    def self.clean
      Paths.ensure_root!

      puts "filc: cleaning build artifacts..."

      dirs = ["build", "pizfix", "filc/test-output"]
      dirs.each do |d|
        path = Paths.root / d
        if path.exist?
          puts "  Removing #{d}/..."
          FileUtils.rm_rf(path)
        end
      end

      puts "✓ Clean complete."
      puts "  Run 'filc build' to rebuild."
    end
  end

  # Minimal TOML parser for our port definition subset
  module SimpleTOML
    def self.parse(text)
      result = {}
      current_section = result
      section_path = []

      text.each_line do |line|
        line = line.sub(/#.*$/, "").strip
        next if line.empty?

        if line =~ /^\[([^\]]+)\]$/
          section_path = $1.split(".")
          current_section = result
          section_path.each do |key|
            current_section[key] ||= {}
            current_section = current_section[key]
          end
        elsif line =~ /^(\w+(?:-\w+)*)\s*=\s*\[(.*)\]$/
          key = $1
          raw = $2.strip
          values = raw.split(",").map { |v| parse_value(v.strip) }
          current_section[key] = values
        elsif line =~ /^(\w+(?:-\w+)*)\s*=\s*(.+)$/
          key = $1
          value = parse_value($2.strip)
          current_section[key] = value
        end
      end
      result
    end

    private

    def self.parse_value(str)
      if str =~ /^"(.*)"$/m
        $1.gsub('\\"', '"')
      elsif str =~ /^'(.*)'$/
        $1
      elsif str =~ /^true$/i
        true
      elsif str =~ /^false$/i
        false
      elsif str =~ /^(\d+)$/
        $1.to_i
      else
        str
      end
    end
  end

  # Port system: build, install, and manage ported libraries
  module PortSystem
    PORTS_DIR = -> { Paths.root / "ports" }
    PREFIX_DIR = -> { Paths.root / "ports" / "prefix" }

    # Load all port definitions from ports/*.toml
    def self.load_ports
      dir = PORTS_DIR.call
      return {} unless dir.exist?
      ports = {}
      Dir.glob("#{dir}/*.toml").each do |file|
        next if File.basename(file) == "filc-ports.toml" # index file
        text = File.read(file)
        data = SimpleTOML.parse(text)
        next unless data["port"] && data["port"]["name"]
        name = data["port"]["name"]
        ports[name] = {
          name:        name,
          version:     data["port"]["version"] || "unknown",
          description: data["port"]["description"] || "",
          homepage:    data["port"]["homepage"] || "",
          source_dir:  data.dig("source", "dir"),
          fetch:       data.dig("source", "fetch"),
          deps:        data.dig("dependencies", "deps") || [],
          build_script: data.dig("build", "script"),
          pc_cflags:   data.dig("pkgconfig", "cflags"),
          pc_libs:     data.dig("pkgconfig", "libs"),
          source_file: file,
        }
      end
      ports
    end

    def self.installed?(name)
      (PREFIX_DIR.call / name / ".built").exist?
    end

    def self.install_prefix(name)
      PREFIX_DIR.call / name
    end

    def self.deps_prefix(name)
      deps = load_ports[name]&.dig(:deps) || []
      deps.map { |d| (PREFIX_DIR.call / d).to_s }.join(":")
    end

    # Topological sort of ports by dependencies
    def self.resolve_order(names, ports = nil)
      ports ||= load_ports
      resolved = []
      visiting = Set.new

      visit = ->(name) do
        raise Error, "Circular dependency detected involving #{name}" if visiting.include?(name)
        return if resolved.include?(name)
        visiting.add(name)

        port = ports[name]
        raise Error, "Unknown port: #{name}" unless port

        port[:deps].each { |dep| visit.call(dep) }
        visiting.delete(name)
        resolved << name
      end

      names.each { |n| visit.call(n) }
      resolved
    rescue Error => e
      raise e
    end

    # List all ports
    def self.list(filter: nil)
      ports = load_ports
      if ports.empty?
        puts "No ports found in #{PORTS_DIR.call}/"
        puts "Run 'filc port create <name>' to create one."
        return
      end

      # Sort by name
      sorted = ports.values.sort_by { |p| p[:name] }

      if filter
        re = Regexp.new(filter, Regexp::IGNORECASE)
        sorted = sorted.select { |p| p[:name] =~ re || p[:description] =~ re }
      end

      if sorted.empty?
        puts "No ports match '#{filter}'"
        return
      end

      printf "%-20s %-12s %s\n", "PORT", "VERSION", "STATUS / DESCRIPTION"
      puts "-" * 70
      sorted.each do |p|
        status = installed?(p[:name]) ? "✓ installed" : "○ not built"
        printf "%-20s %-12s %s\n", p[:name], p[:version], status
        if p[:deps].any?
          printf "%-20s %-12s deps: %s\n", "", "", p[:deps].join(", ")
        end
        unless p[:description].empty?
          printf "%-20s %-12s %s\n", "", "", p[:description][0..50]
        end
        puts
      end

      installed_count = ports.values.count { |p| installed?(p[:name]) }
      puts "#{installed_count}/#{ports.size} ports installed"
    end

    # Show port info
    def self.info(name)
      ports = load_ports
      port = ports[name]
      raise Error, "Unknown port: #{name}" unless port

      puts "#{port[:name]} #{port[:version]}"
      puts "  #{port[:description]}"
      puts "  Homepage: #{port[:homepage]}" unless port[:homepage].empty?
      puts
      puts "  Status:    #{installed?(name) ? '✓ installed' : '○ not built'}"
      puts "  Source:    #{port[:source_dir] || 'external (fetch)'}"
      puts "  Depends:   #{port[:deps].any? ? port[:deps].join(', ') : '(none)'}"
      puts "  Installed: #{install_prefix(name)}" if installed?(name)
      if port[:pc_cflags]
        puts "  pkg-config:"
        puts "    cflags: #{port[:pc_cflags]}"
        puts "    libs:   #{port[:pc_libs]}"
      end
    end

    # Show dependency tree
    def self.tree(name, indent: 0, visited: Set.new, ports: nil)
      ports ||= load_ports
      port = ports[name]
      raise Error, "Unknown port: #{name}" unless port

      prefix = "  " * indent
      marker = installed?(name) ? "✓" : "○"
      puts "#{prefix}#{marker} #{name} #{port[:version]}"

      return if visited.include?(name)
      visited.add(name)

      port[:deps].each do |dep|
        tree(dep, indent: indent + 1, visited: visited, ports: ports)
      end
    end

    # Build a single port
    def self.build_port(name, ports = nil)
      ports ||= load_ports
      port = ports[name]
      raise Error, "Unknown port: #{name}" unless port

      return true if installed?(name)

      # Build dependencies first
      port[:deps].each do |dep|
        build_port(dep, ports)
      end

      puts
      puts "═══ Building #{name} #{port[:version]} ═══"
      puts "  Description: #{port[:description]}"
      puts "  Dependencies: #{port[:deps].join(', ')}" if port[:deps].any?

      source_dir = port[:source_dir]
      unless source_dir && (Paths.root / source_dir).exist?
        if port[:fetch]
          puts "  Source not found. Run 'filc port fetch #{name}' to download."
          raise Error, "Source for #{name} not found at #{source_dir}. Run 'filc port fetch #{name}'."
        else
          raise Error, "Source directory not found: #{source_dir}"
        end
      end

      prefix = install_prefix(name)
      deps_prefix_val = port[:deps].map { |d| install_prefix(d) }.join(":")

      # Create prefix directory
      FileUtils.mkdir_p(prefix)
      FileUtils.mkdir_p("#{prefix}/lib/pkgconfig")
      FileUtils.mkdir_p("#{prefix}/include")

      # Write build script
      script_path = "#{prefix}/build.sh"
      build_content = <<~SCRIPT
        #!/bin/bash
        set -e
        export PREFIX="#{prefix}"
        export DEPS_PREFIX="#{deps_prefix_val}"
        export PATH="#{Paths.build_dir}/bin:$PATH"
        #{port[:build_script]}
      SCRIPT
      File.write(script_path, build_content)
      FileUtils.chmod(0755, script_path)

      # Run the build
      Dir.chdir(Paths.root / source_dir) do
        success = system("bash", script_path)
        unless success
          FileUtils.rm_f("#{prefix}/.built")
          raise Error, "Build failed for #{name}. Check #{script_path}"
        end
      end

      # Generate pkg-config file
      if port[:pc_cflags] || port[:pc_libs]
        generate_pkgconfig(name, port, prefix)
      end

      # Mark as built
      File.write("#{prefix}/.built", Time.now.to_s)
      puts "  ✓ #{name} installed to #{prefix}"
      true
    end

    def self.generate_pkgconfig(name, port, prefix)
      pc_path = "#{prefix}/lib/pkgconfig/#{name}.pc"
      libdir = "#{prefix}/lib"
      includedir = "#{prefix}/include"
      deps_str = port[:deps].map { |d| d }.join(" ")

      pc_content = <<~PC
        prefix=#{prefix}
        libdir=#{libdir}
        includedir=#{includedir}

        Name: #{name}
        Description: #{port[:description]}
        Version: #{port[:version]}
        #{port[:deps].any? ? "Requires: #{deps_str}" : ""}
        Cflags: #{port[:pc_cflags]&.gsub('${includedir}', includedir)&.gsub('${prefix}', prefix) || "-I${includedir}"}
        Libs: #{port[:pc_libs]&.gsub('${libdir}', libdir)&.gsub('${prefix}', prefix) || "-L${libdir}"}
      PC

      File.write(pc_path, pc_content.strip + "\n")
      puts "  Generated #{pc_path}"
    end

    # Install one or more ports (with deps)
    def self.install(names)
      Paths.ensure_root!
      raise Error, "Fil-C compiler not built. Run 'filc build' first." unless Paths.clang.exist?

      ports = load_ports
      raise Error, "No ports found. Run 'filc port list'." if ports.empty?

      all_names = resolve_order(names, ports)

      puts "filc: building #{all_names.size} port(s): #{all_names.join(', ')}"
      puts "  Order: #{all_names.join(' → ')}"
      puts

      all_names.each do |name|
        build_port(name, ports)
      end

      puts
      puts "✓ All ports built."
      puts "  Use pkg-config to compile against them:"
      pc_paths = all_names.map { |n| "#{PREFIX_DIR.call}/#{n}/lib/pkgconfig" }
      puts "  export PKG_CONFIG_PATH=#{pc_paths.join(':')}"
      puts "  filc compile myapp.c $(pkg-config --cflags --libs #{all_names.join(' ')})"
    end

    # Search ports
    def self.search(regex)
      list(filter: regex)
    end

    # Fetch a port's source (clone/download)
    def self.fetch(name)
      ports = load_ports
      port = ports[name]
      raise Error, "Unknown port: #{name}" unless port

      fetch_info = port[:fetch]
      raise Error, "#{name} has no fetch URL. Source must be added manually." unless fetch_info

      source_dir = Paths.root / port[:source_dir]

      if source_dir.exist?
        puts "Source already exists at #{port[:source_dir]}"
        return
      end

      case fetch_info["type"]
      when "git"
        url = fetch_info["url"]
        tag = fetch_info["tag"]
        puts "Cloning #{name} from #{url} (tag: #{tag})..."
        Dir.chdir(Paths.root / "projects") do
          system("git", "clone", "--depth", "1", "--branch", tag, url, File.basename(port[:source_dir]))
        end
        puts "  ✓ Source fetched to #{port[:source_dir]}"
        puts "  Next: commit the source to the repo with:"
        puts "    git add #{port[:source_dir]}"
        puts "    git commit -m 'add #{name} #{port[:version]} source'"
      else
        raise Error, "Unsupported fetch type: #{fetch_info['type']}"
      end
    end
  end

  # One-command setup: build everything needed for development
  module Setup
    def self.run(components: nil)
      Paths.ensure_root!

      puts "═══ Fil-C Setup ═══"
      puts

      # Step 1: Check environment
      puts "[1/3] Checking environment..."
      ok = Doctor.run
      unless ok
        puts
        puts "Missing required tools. Run:"
        puts "  mise install           # for cmake, ninja, ruby"
        puts "  mise run install-deps   # for system packages"
        raise Error, "Environment not ready."
      end

      # Step 2: Build Fil-C
      puts
      puts "[2/3] Building Fil-C compiler + runtime..."
      if components
        components.each { |c| Builder.run(component: c) }
      else
        Builder.run
      end

      # Step 3: Build core ports
      puts
      puts "[3/3] Building core ports (zlib, openssl)..."
      if Paths.clang.exist?
        PortSystem.install(["openssl"]) rescue puts "  (port build skipped — no ports or deps missing)"
      end

      puts
      puts "═══ Fil-C is ready ═══"
      puts "  Compile:  filc compile hello.c -o hello"
      puts "  Run:      filc run hello.c"
      puts "  Test:     filc test"
      puts "  Ports:    filc port list"
      puts
      puts "  Quick test:"
      puts "    echo '#include <stdfil.h>' > /tmp/test.c"
      puts "    echo 'int main() { zprintf(\"Hello from Fil-C!\\\\n\"); return 0; }' >> /tmp/test.c"
      puts "    filc run /tmp/test.c"
    end
  end
end

# CLI entry point
if __FILE__ == $PROGRAM_NAME
  command = ARGV.shift

  def print_help
    puts "filc — The Fil-C developer CLI"
    puts
    puts "Usage: filc COMMAND [OPTIONS]"
    puts
    puts "Commands:"
    printf "  %-35s %s\n", "doctor",                    "Check development environment"
    printf "  %-35s %s\n", "build",                      "Build Fil-C (full or incremental)"
    printf "  %-35s %s\n", "build --component=NAME",     "Build a single component"
    printf "  %-35s %s\n", "build --component=list",     "List available components"
    printf "  %-35s %s\n", "compile [OPTS] FILE...",     "Compile C/C++ with Fil-C"
    printf "  %-35s %s\n", "  --output=FILE",            "    Output binary name"
    printf "  %-35s %s\n", "  --opt=FLAGS",              "    Optimization flags (default: -O)"
    printf "  %-35s %s\n", "  --std=STD",                "    C/C++ standard (c11, c++20, etc.)"
    printf "  %-35s %s\n", "run [OPTS] FILE...",         "Compile and run a Fil-C program"
    printf "  %-35s %s\n", "test",                       "Run test suite"
    printf "  %-35s %s\n", "test --filter=REGEX",        "Run matching tests only"
    printf "  %-35s %s\n", "test --verbose",             "Verbose test output"
    printf "  %-35s %s\n", "test --no-run",              "Compile tests only, don't run"
    printf "  %-35s %s\n", "info",                       "Project and environment info"
    printf "  %-35s %s\n", "shell",                      "Start shell with Fil-C on PATH"
    printf "  %-35s %s\n", "clean",                      "Clean all build artifacts"
    printf "  %-35s %s\n", "setup",                      "One-command setup (doctor + build + ports)"
    puts
    puts "Port system:"
    printf "  %-35s %s\n", "port list",                  "List available ports"
    printf "  %-35s %s\n", "port install NAME...",       "Build port(s) + dependencies"
    printf "  %-35s %s\n", "port info NAME",             "Detailed port info"
    printf "  %-35s %s\n", "port tree NAME",             "Show dependency tree"
    printf "  %-35s %s\n", "port search REGEX",          "Search ports"
    printf "  %-35s %s\n", "port fetch NAME",            "Download port source"
    puts
    puts "Examples:"
    puts "  filc doctor"
    puts "  filc build"
    puts "  filc run -o hello hello.c"
    puts "  filc test --filter=alloc"
    puts
    puts "Quick debugging env vars:"
    puts "  FUGC_STW=1 FUGC_SCRIBBLE=1 FUGC_VERIFY=1 FILC_DUMP_SETUP=1 filc run mytest.c"
  end

  unless command
    print_help
    exit 1
  end

  begin
    case command
    when "doctor"
      ok = FilC::Doctor.run
      exit(ok ? 0 : 1)

    when "build"
      component = nil
      argv = []
      ARGV.each do |arg|
        if arg =~ /^--component=(.+)$/
          component = $1
        else
          argv << arg
        end
      end
      ARGV.replace(argv)

      if component == "list"
        FilC::Builder.list_components
      elsif component
        FilC::Builder.run(component: component)
      else
        FilC::Builder.run
      end

    when "compile"
      output = nil
      opt = "-O"
      std = nil
      argv = []
      ARGV.each do |arg|
        if arg =~ /^--output=(.+)$/
          output = $1
        elsif arg =~ /^--opt=(.+)$/
          opt = $1
        elsif arg =~ /^--std=(.+)$/
          std = $1
        else
          argv << arg
        end
      end

      raise FilC::Error, "No input files specified" if argv.empty?
      FilC::Compiler.compile(argv, output: output, opt: opt, std: std)

    when "run"
      output = nil
      opt = "-O"
      std = nil
      argv = []
      ARGV.each do |arg|
        if arg =~ /^--output=(.+)$/
          output = $1
        elsif arg =~ /^--opt=(.+)$/
          opt = $1
        elsif arg =~ /^--std=(.+)$/
          std = $1
        else
          argv << arg
        end
      end
      raise FilC::Error, "No input files specified" if argv.empty?
      FilC::Runner.run(argv, output: output, opt: opt, std: std)

    when "test"
      filter = nil
      verbose = false
      no_run = false
      ARGV.each do |arg|
        if arg =~ /^--filter=(.+)$/
          filter = $1
        elsif arg == "--verbose" || arg == "-v"
          verbose = true
        elsif arg == "--no-run"
          no_run = true
        end
      end
      FilC::Tester.run(filter: filter, verbose: verbose, no_run: no_run)

    when "info"
      FilC::Info.print

    when "shell"
      FilC::Shell.start

    when "clean"
      FilC::Cleaner.clean

    when "setup"
      FilC::Setup.run

    when "port"
      subcmd = ARGV.shift
      case subcmd
      when "list"
        FilC::PortSystem.list
      when "install"
        names = ARGV
        raise FilC::Error, "Usage: filc port install <name> [<name>...]" if names.empty?
        FilC::PortSystem.install(names)
      when "info"
        name = ARGV.shift
        raise FilC::Error, "Usage: filc port info <name>" unless name
        FilC::PortSystem.info(name)
      when "tree"
        name = ARGV.shift
        raise FilC::Error, "Usage: filc port tree <name>" unless name
        FilC::PortSystem.tree(name)
      when "search"
        regex = ARGV.shift
        raise FilC::Error, "Usage: filc port search <regex>" unless regex
        FilC::PortSystem.search(regex)
      when "fetch"
        name = ARGV.shift
        raise FilC::Error, "Usage: filc port fetch <name>" unless name
        FilC::PortSystem.fetch(name)
      else
        $stderr.puts "filc: unknown port subcommand '#{subcmd}'"
        $stderr.puts "  Available: list, install, info, tree, search"
        exit 1
      end

    when "--version", "-V"
      puts "filc #{FilC::VERSION}"

  when "--help", "-h", "help"
      print_help
      exit 0

    else
      $stderr.puts "filc: unknown command '#{command}'"
      $stderr.puts "Run 'filc' without arguments for help."
      exit 1
    end
  rescue FilC::Error => e
    $stderr.puts "filc: #{e.message}"
    exit 1
  rescue Interrupt
    puts "\nfilc: interrupted"
    exit 130
  end
end
