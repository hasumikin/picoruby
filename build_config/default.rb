#
# This build config works also in mruby/build_config
#

MRuby::Build.new do |conf|
  conf.toolchain

  disable_presym
  conf.mrbcfile = "#{conf.build_dir}/bin/picorbc"

  ENV['MRUBYC_BRANCH'] = "mrubyc3"
  # ENV['MRUBYC_REVISION'] = "4e91963"
  conf.gem github: 'hasumikin/mruby-mrubyc', branch: '3.0.0'
  conf.gem github: 'hasumikin/mruby-pico-compiler', branch: '3.0.0'
  conf.gem github: 'hasumikin/mruby-bin-picorbc', branch: '3.0.0'
  conf.gem github: 'hasumikin/mruby-bin-picoruby', branch: '3.0.0'
  conf.gem github: 'hasumikin/mruby-bin-picoirb', branch: '3.0.0'

  conf.cc.defines << "DISABLE_MRUBY"
  if ENV["PICORUBY_DEBUG_BUILD"]
    conf.cc.defines << "PICORUBY_DEBUG"
    conf.cc.flags.flatten!
    conf.cc.flags.reject! { |f| %w(-g -O3).include? f }
    conf.cc.flags << "-g3"
    conf.cc.flags << "-O0"
  else
    conf.cc.defines << "NDEBUG"
  end
  conf.cc.defines << "MRBC_ALLOC_LIBC"
  conf.cc.defines << "REGEX_USE_ALLOC_LIBC"
  conf.cc.defines << "MRBC_USE_HAL_POSIX"
  conf.cc.defines << "MRBC_USE_MATH"
  conf.cc.defines << "MAX_SYMBOLS_COUNT=#{ENV['MAX_SYMBOLS_COUNT'] || 700}"
end
