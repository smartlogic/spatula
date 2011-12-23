# Prepare :server: for chef solo to run on it
module Spatula
  class Prepare < SshCommand

    DEFAULT_RUBY_VERSION = "1.9.2-p180"
    DEFAULT_RUBYGEMS_VERSION = "1.6.2"

    def run

      if @key_file and !@upload_key
        @upload_key = true
      end

      upload_ssh_key if @upload_key
      send "run_for_#{os}"
    end

    def os
      etc_issue = `#{ssh_command("cat /etc/issue")}`
      case etc_issue
      when /ubuntu/i
        "ubuntu"
      when /debian/i
        "debian"
      when ""
        raise "Couldn't get system info from /etc/issue. Please check your SSH credentials."
      else
        raise "Sorry, we currently only support prepare on ubuntu, debian & fedora. Please fork http://github.com/trotter/spatula and add support for your OS. I'm happy to incorporate pull requests."
      end
    end

    def run_for_ubuntu
      ssh "#{sudo} apt-get update"
      ssh "#{sudo} apt-get install -y build-essential zlib1g-dev libssl-dev libreadline5-dev curl rsync git-core"
      install_rvm
      install_openssl
      install_ruby
      install_rubygems
      install_chef
    end

    def run_for_debian
      ssh "#{sudo} apt-get update"
      ssh "#{sudo} apt-get install -y build-essential zlib1g-dev libssl-dev libreadline5-dev curl rsync git-core"
      install_rvm
      install_openssl
      install_ruby
      install_rubygems
      install_chef
    end

    def ruby_version
      @ruby_version || DEFAULT_RUBY_VERSION
    end

    def rubygems_version
      @rubygems_version || DEFAULT_RUBYGEMS_VERSION
    end

    def ruby186?
      ruby_version =~ /1\.8\.6/
    end

    def install_rvm
      ssh "#{sudo} bash --profile < <(curl -s https://raw.github.com/wayneeseguin/rvm/master/binscripts/rvm-installer )"
      ssh "whoami | xargs #{sudo} usermod -a -G rvm"
      ssh "#{sudo} usermod -a -G rvm root"
    end

    def install_openssl
      return unless ruby186?
      ssh "wget http://www.openssl.org/source/openssl-0.9.8g.tar.gz"
      ssh "tar xzf openssl-0.9.8g.tar.gz"
      ssh "cd openssl-0.9.8g && ./config --prefix=/opt/local --openssldir=/opt/local/openssl shared && make && #{sudo} make install"
    end

    def install_ruby
      if ruby186?
        ssh "rvm install #{ruby_version} --with-openssl-dir=/opt/local"
      else
        ssh "rvm install #{ruby_version}"
      end
      ssh "rvm use --default #{ruby_version}"
    end

    def install_rubygems
      return if ruby_version =~ /1\.9\.[0-9]/ && @rubygems_version.nil? # no need for rubygems install on 1.9.2, unless a specific version was requested at the command line
      ssh "rvm rubygems #{rubygems_version}"
    end

    def install_chef
      # this combination supports ruby 1.8.6
      version = ruby186? ? "2.5" : nil
      install_gem("rdoc", version)

      install_gem("ohai")
      if ruby186?
        install_gem("bunny", "0.7.6")
        install_gem("highline", "1.6.2")
        install_gem("polyglot", "0.3.2")
      end
      install_gem("chef")
    end

    def install_gem(gem, version = nil)
      version = "-v #{version}" if version
      ssh "rvm all do gem install #{gem} #{version} --no-ri --no-rdoc --source http://gems.rubyforge.org"
    end

    def sudo
      ssh('which sudo > /dev/null 2>&1') ? 'sudo' : ''
    end

    def upload_ssh_key
      authorized_file = "~/.ssh/authorized_keys"

      unless @key_file
        %w{rsa dsa}.each do |key_type|
          filename = "#{ENV['HOME']}/.ssh/id_#{key_type}.pub"
          if File.exists?(filename)
            @key_file = filename
            break
          end
        end
      end

      raise "Key file '#{@key_file}' not found: aborting." unless File.exists?(@key_file)

      key = File.open(@key_file).read.split(' ')[0..1].join(' ')

      ssh "mkdir -p .ssh && echo #{key} >> #{authorized_file}"
      ssh "cat #{authorized_file} | sort | uniq > #{authorized_file}.tmp && mv #{authorized_file}.tmp #{authorized_file}"
      ssh "chmod 0700 .ssh && chmod 0600 #{authorized_file}"
    end
  end
end
