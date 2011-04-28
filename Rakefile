require 'rake'
require 'erb'

task :default => [:bash, :bin, :ruby, :vim]

desc 'configure ~/.config symlink'
task :init do
  $homedir = File.expand_path '~'
  $currdir = File.expand_path '.' 
  $dotconf = File.join $homedir, '.config'
  relink_file $currdir, $dotconf
  $homebin = File.join $homedir, 'bin'
end

desc 'configure bash links'
task :bash => :init do
  %w[bashrc bash_profile inputrc nanorc ackrc].each do |file|
    relink_file File.join($dotconf, 'bash', file), File.join($homedir, ".#{file}")
  end
end

desc 'configure ~/bin'
task :bin => :init do
  FileUtil.mkdir $homebin unless File.exist? $homebin
  %w[vcprompt pg beautify ack].each do |file|
    source = File.join $dotconf, 'bin', file
    FileUtils.chmod 0755, source
    relink_file source, File.join($homebin, file)
  end
end

desc 'configure ruby links'
task :ruby => :init do
  %w[rdebugrc irbrc gemrc autotest].each do |file|
    relink_file File.join($dotconf, 'ruby', file), File.join($homedir, ".#{file}")
  end
end

desc 'configure vim links'
task :vim => :init do
  relink_file File.join($dotconf, 'vim'), File.join($homedir, '.vim')
  %w[vimrc gvimrc].each do |file|
    relink_file File.join($dotconf, 'vim', file), File.join($homedir, ".#{file}")
  end
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
    FileUtils.copy source, target
    system "plutil -convert xml1 #{target}"
  end
end

desc 'configure terminal'
task :terminal => :init do
  filename = 'com.apple.Terminal.plist'
  target = File.join $homedir, 'Library', 'Preferences', filename
  source = File.join $dotconf, 'terminal', filename
  backup = "#{source}.bak"
  FileUtils.copy target, backup unless File.exist?(backup)
  relink_file source, target
end

namespace :install do
  desc 'download latest vcprompt'
  task :vcprompt => :init do
    system "curl -s https://github.com/xvzf/vcprompt/raw/master/bin/vcprompt > bin/vcprompt"
    FileUtils.chmod 0755, "bin/vcprompt"
  end
  
  desc 'install pow.  see http://pow.cx/manual.html'
  task :pow do
    system "curl get.pow.cx | sh"
  end
end

namespace :remove do
  desc 'uninstall pow'
  task :pow do
    system "curl get.pow.cx/uninstall.sh | sh"
  end
end

def link_file(source, target)
  puts "linking #{target}"
  FileUtils.ln_sf source, target
end

def remove_file(file)
  FileUtils.rm file, :force => true if File.exist?(file)
end

def relink_file(source, target)
  remove_file target
  link_file source, target
end

def generate(source, target)
  puts "generating #{target}"
  File.open(target, 'w') do |new_file|
    new_file.write ERB.new(File.read(source)).result(binding)
  end
end
