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
