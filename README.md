Kris' Dot Files
===============

My unix shell and vim configuration files

Installation
------------

	$ git clone git://github.com/kriswill/dotfiles ~/src/dotfiles
	$ cd ~/src/dotfiles
	$ rake

This will produce the following links:

* ~/.config -> ~/src/dotfiles
* ~/.bash_profile -> ~/.config/bash/bashprofile
* ~/.bashrc -> ~/.config/bash/bashrc
* ~/.vimrc -> ~/.config/vim/vimrc
* ~/.gvimrc -> ~/.config/vim/gvimrc

Bourne-Again SHell
------------------

I use the default BASH shell that comes configured on Mac OS/X 10.6.7.  The rake command will link the appropriate dot files in the home directory.

Mac OS/X Terminal Settings
--------------------------

Ruby configuration
------------------


VIM
---

I use MacVIM on OS/X.  The configuration files are setup to use this version of VIM (7.3 as of this writing).  I use [Pathogen](https://github.com/tpope/vim-pathogen) to configure VIM plugins in the `.config/vim/bundles` directory.  Each plugin is configured as a git submodule.  To update the plugins run:

	$ cd ~/.config
	$ git submodule update --init