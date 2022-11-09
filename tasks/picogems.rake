MRuby.each_target do |build|

  # picogems to be required in Ruby
  mrbfiles = Array.new
  gems.each do |gem|
    if gem.name.start_with?("picoruby-")
      mrbfile = "#{build_dir}/mrbgems/#{gem.name}/mrblib/#{gem.name.sub(/\Apicoruby-(bin-)?/,'')}.c"
      mrbfiles << mrbfile
      file mrbfile => gem.rbfiles do |t|
        next if t.prerequisites.empty?
        mkdir_p File.dirname(t.name)
        File.open(t.name, 'w') do |f|
          name = File.basename(t.name, ".c").gsub('-','_')
          mrbc.run(f, t.prerequisites, name, false)
          f.puts
          f.puts "void mrbc_#{name}_init();"
        end
      end
    end
  end

  # prsh executable commands
  executable_mrbfiles = Array.new
  if shell_gem = gems.find{|gem| gem.name == "picoruby-shell"}
    executable_dir = "#{build_dir}/mrbgems/picoruby-shell/shell_executables"
    directory executable_dir
    Dir.glob("#{shell_gem.dir}/shell_executables/*.rb") do |rbfile|
      mrbfile = "#{executable_dir}/#{rbfile.pathmap('%n')}.c"
      file mrbfile => [rbfile, executable_dir] do |t|
        File.open(t.name, 'w') do |f|
          mrbc.run(f, t.prerequisites[0], "executable_#{t.name.pathmap("%n").gsub('-', '_')}", false)
        end
      end
      executable_mrbfiles << mrbfile
    end
  end

  self.libmruby_objs << objfile("#{build_dir}/mrbgems/picogem_init")
  file objfile("#{build_dir}/mrbgems/picogem_init") => ["#{build_dir}/mrbgems/picogem_init.c"]

  file "#{build_dir}/mrbgems/picogem_init.c" => [*mrbfiles, *executable_mrbfiles, MRUBY_CONFIG, __FILE__] do |t|
    mkdir_p File.dirname t.name
    open(t.name, 'w+') do |f|
      f.puts <<~PICOGEM
        #include <stdio.h>
        #include <stdbool.h>
        #include <mrubyc.h>
        #include <alloc.h>
      PICOGEM
      f.puts
      mrbfiles.each do |mrb|
        f.puts "#include \"#{mrb}\"" if File.exist?(mrb)
      end
      f.puts
      f.puts <<~PICOGEM
        typedef struct picogems {
          const char *name;
          const uint8_t *mrb;
          void (*initializer)(void);
          bool required;
        } picogems;
      PICOGEM
      f.puts
      f.puts "static picogems gems[] = {"
      mrbfiles.each do |mrb|
        name = File.basename(mrb, ".c")
        f.puts "  {\"#{name}\", #{name.gsub('-','_')}, mrbc_#{name.gsub('-','_')}_init, false}," if File.exist?(mrb)
      end
      f.puts "  {NULL, NULL, NULL, true} /* sentinel */"
      f.puts "};"
      f.puts
      f.puts <<~PICOGEM
        static int
        gem_index(const char *name)
        {
          if (!name) return -1;
          for (int i = 0; ; i++) {
            if (gems[i].name == NULL) {
              return -1;
            } else if (strcmp(name, gems[i].name) == 0) {
              return i;
            }
          }
        }

        static int
        load_model(const uint8_t *mrb)
        {
          mrbc_vm *vm = mrbc_vm_open(NULL);
          if (vm == 0) {
            console_printf("Error: Can't open VM.\\n");
            return 0;
          }
          if (mrbc_load_mrb(vm, mrb) != 0) {
            console_printf("Error: Illegal bytecode.\\n");
            return 0;
          }
          mrbc_vm_begin(vm);
          mrbc_vm_run(vm);
          mrbc_raw_free(vm);
          return 1;
        }

        static void
        c_require(mrb_vm *vm, mrb_value *v, int argc)
        {
          const char *name = (const char *)GET_STRING_ARG(1);
          int i = gem_index(name);
          if (i < 0) {
            char buff[64];
            sprintf(buff, "cannot find such gem -- %s", name);
            mrbc_raise(vm, MRBC_CLASS(RuntimeError), buff);
            return;
          }
          if (!gems[i].required && load_model(gems[i].mrb)) {
            if (gems[i].initializer) gems[i].initializer();
            gems[i].required = true;
            SET_TRUE_RETURN();
          } else {
            SET_FALSE_RETURN();
          }
        }
      PICOGEM
      f.puts

      # shell executables
      executable_mrbfiles.each do |mrb|
        f.puts "#include \"#{mrb}\"" if File.exist?(mrb)
      end
      f.puts
      f.puts <<~PICOGEM
        typedef struct shell_executables {
          const char *name;
          const uint8_t *mrb;
        } shell_executables;
      PICOGEM
      f.puts
      f.puts "static shell_executables executables[] = {"
      executable_mrbfiles.each do |mrb|
        name = File.basename(mrb, ".c")
        f.puts "  {\"#{name}\", executable_#{name}}," if File.exist?(mrb)
      end
      f.puts "  {NULL, NULL} /* sentinel */"
      f.puts "};"
      f.puts
      f.puts <<~PICOGEM
        static void
        c__next_executable(mrb_vm *vm, mrb_value *v, int argc)
        {
          static int i = 0;
          if (executables[i].name) {
            const uint8_t *mrb = executables[i].mrb;
            mrbc_value hash = mrbc_hash_new(vm, 2);
            mrbc_value name = mrbc_string_new_cstr(vm, (char *)executables[i].name);
            mrbc_hash_set(&hash,
              &mrbc_symbol_value(mrbc_str_to_symid("name")),
              &name
            );
            uint32_t codesize = (mrb[8] << 24) + (mrb[9] << 16) + (mrb[10] << 8) + mrb[11];
            mrbc_value code_val = mrbc_string_new(vm, mrb, codesize);
            mrbc_hash_set(&hash,
              &mrbc_symbol_value(mrbc_str_to_symid("code")),
              &code_val
            );
            SET_RETURN(hash);
            i++;
          } else {
            SET_NIL_RETURN();
          }
        }
      PICOGEM
      f.puts <<~PICOGEM
        void
        mrbc_require_init(void)
        {
          mrbc_define_method(0, mrbc_class_object, "_next_executable", c__next_executable);
          mrbc_define_method(0, mrbc_class_object, "require", c_require);
        }
      PICOGEM
    end
  end
end
