module Spatula
  class SshCommand
    def self.run(*args)
      new(*args).run
    end

    def initialize(server, port=nil, login=nil, identity=nil, upload_key=nil, key_file=nil, ruby_version=nil, rubygems_version=nil, http_proxy=nil)
      @server = server
      @port   = port
      @port_switch = port ? " -p #{port}" : ''
      @login_switch = login ? "-l #{login}" : ''
      @identity_switch = identity ? %Q|-i "#{identity}"| : ''
      @upload_key = upload_key
      @key_file = key_file
      @ruby_version = ruby_version
      @rubygems_version = rubygems_version
      @http_proxy = http_proxy
    end

    def ssh(command)
      sh ssh_command(command)
    end

    def ssh_command_start
      if @http_proxy
        "http_proxy=#{@http_proxy} bash --login -c"
      else
        'bash --login -c'
      end
    end

    def ssh_command(command)
      %Q|ssh -t#{ssh_opts} #@server '#{ssh_command_start} "#{command.gsub('"', '\\"')}"'|
    end

    def ssh_opts
      "#@port_switch #@login_switch #@identity_switch"
    end

    private
      def sh(command)
        system command
      end
  end
end
