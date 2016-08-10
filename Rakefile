require 'rake'
require 'erb'

task :default => [:bash, :bin, :autojump, :ruby, :ctags]

desc 'configure ~/.config symlink'
task :init do
  $homedir = File.expand_path '~'
  $currdir = File.expand_path '.'
  $dotconf = File.join $homedir, '.config'
  relink_file $currdir, $dotconf
  $homebin = File.join $homedir, 'bin'
  mkdir $homebin unless File.exist? $homebin
end

desc 'configure bash links'
task :bash => :init do
  %w[bashrc bash_profile inputrc ackrc].each do |file|
    relink_file File.join($dotconf, 'bash', file), File.join($homedir, ".#{file}")
  end
end

desc 'configure autojump'
task :autojump => :init do
  source = File.join $dotconf, 'bash', 'autojump', 'autojump'
  target = File.join $homebin, 'autojump'
  relink_file source, target
  chmod 0755, target
end

desc 'configure ~/bin'
task :bin => :init do
  %w[pg beautify jsbeautify ack cloc git-wtf vcprompt].each do |file|
    source = File.join $dotconf, 'bin', file
    chmod 0755, source
    relink_file source, File.join($homebin, file)
  end
end

desc 'configure ruby links'
task :ruby => :init do
  %w[rdebugrc irbrc gemrc autotest].each do |file|
    relink_file File.join($dotconf, 'ruby', file), File.join($homedir, ".#{file}")
  end
end

desc 'configure ctags'
task :ctags => :init do
  relink_file File.join($dotconf, 'dev', 'ctags'), File.join($homedir, '.ctags')
end

# WIP
desc 'configure git links'
task :git => :init do
  #erb = File.join($dotconf, 'git', 'gitconfig.erb')
  #gitconfig = File.join($dotconf, 'git', 'gitconfig')
  #generate(erb, gitconfig) unless File.exists gitconfig

   ['gitrc', 'gitconfig', 'gitignore', 'gitk', 'gitattributes'].each do |file|
     relink_file File.join($dotconf, 'git', file), File.join($homedir, ".#{file}")
   end
end

desc 'backup terminal settings'
task :backup_terminal_settings => :init do
  filename = 'com.apple.Terminal.plist'
  source = File.join $homedir, 'Library', 'Preferences', filename
  if File.exist?(source) then
    target = File.join $dotconf, 'terminal', filename
    copy source, target
    system "plutil -convert xml1 #{target}"
  end
end

desc 'configure terminal'
task :terminal => :init do
  filename = 'com.apple.Terminal.plist'
  target = File.join $homedir, 'Library', 'Preferences', filename
  source = File.join $dotconf, 'terminal', filename
  backup = "#{source}.bak"
  copy target, backup unless File.exist?(backup)
  relink_file source, target
end

namespace :install do
  desc 'download latest vcprompt'
  # task :vcprompt => :init do
  #   system "curl -s https://github.com/xvzf/vcprompt/raw/master/bin/vcprompt > bin/vcprompt"
  #   chmod 0755, "bin/vcprompt"
  # end

  # desc 'install pow.  see http://pow.cx/manual.html'
  # task :pow do
  #   system "curl get.pow.cx | sh"
  # end
end

namespace :uninstall do
  # desc 'uninstall pow'
  # task :pow do
  #   system "curl get.pow.cx/uninstall.sh | sh"
  # end
end

def relink_file(source, target)
  remove_file file, force: true
  puts "linking #{target}"
  ln_sf source, target
end

def generate(source, target)
  puts "generating #{target}"
  File.open(target, 'w') do |new_file|
    new_file.write ERB.new(File.read(source)).result(binding)
  end
end
