MRuby::Gem::Specification.new('picoruby-mrubyc') do |spec|
  spec.license = 'MIT'
  spec.authors = 'HASUMI Hitoshi'
  spec.summary = 'mruby/c library'

  mrubyc_dir = "#{dir}/repos/mrubyc"

  file mrubyc_dir do
    branch = ENV['MRUBYC_BRANCH'] || "master"
    revision = ENV['MRUBYC_REVISION']
    FileUtils.cd "#{dir}/repos" do
      sh "git clone -b #{branch} https://github.com/mrubyc/mrubyc.git"
    end
    if revision
      FileUtils.cd "#{dir}/repos/mrubyc" do
        sh "git checkout #{revision}"
      end
    end
  end

  mrubyc_srcs = %w(alloc   c_math    c_range  console keyvalue rrt0    vm
                   c_array c_numeric c_string error   load     symbol
                   c_hash  c_object  class    global  value)

      hal_dir = cc.defines.find { |d|
        d.start_with? "MRBC_USE_HAL"
      }.then { |hal|
        if hal.nil?
          cc.defines << "MRBC_USE_HAL=#{MRUBY_ROOT}/include/hal_no_impl"
          "#{MRUBY_ROOT}/include/hal_no_impl"
        elsif hal.start_with?("MRBC_USE_HAL_")
          "#{dir}/repos/mrubyc/src/#{hal.match(/\A(MRBC_USE_)(.+)\z/)[2].downcase}"
        else
          "#{dir}/repos/mrubyc/src/#{hal.match(/\A(MRBC_USE_HAL=)(.+)\z/)[2]}"
        end
      }
      cc.include_paths << hal_dir
      #file objfile("#{build_dir}/src/hal/hal") => "#{hal_dir}/hal.c" do |f|
      #  cc.run f.name, f.prerequisites.first
      #end
#  binding.irb
#  if cc.defines.include?("DISABLE_MRUBY")
#    build.libmruby_objs.clear
#  end
build.libmruby_objs.flatten!.delete_if do |obj|
  obj.end_with? "mrblib.o"
end
#  binding.irb
  (mrubyc_srcs << "mrblib").each do |mrubyc_src|
    obj = objfile("#{build_dir}/src/#{mrubyc_src}")
    build.libmruby_objs << obj
    file obj => "#{mrubyc_dir}/src/#{mrubyc_src}.c" do |f|
      cc.run f.name, f.prerequisites.first
    end
    file "#{mrubyc_dir}/src/#{mrubyc_src}.c" => mrubyc_dir
  end
  file "#{mrubyc_dir}/mrblib" => mrubyc_dir

  file "#{build_dir}/src/mrblib.c" => [build.mrbcfile, "#{mrubyc_dir}/mrblib"] do |f|
    mrblib_sources = Dir.glob("#{mrubyc_dir}/mrblib/*.rb").join(" ")
    mkdir_p File.dirname(f.name)
    sh "#{build.mrbcfile} -B mrblib_bytecode -o #{f.name} #{mrblib_sources}"
  end

  file objfile("#{build_dir}/src/mrblib") => "#{build_dir}/src/mrblib.c" do |f|
    cc.run f.name, f.prerequisites.first
  end

end
