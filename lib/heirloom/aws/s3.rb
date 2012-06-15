module Heirloom

  class AWS
    class S3

      def initialize(args)
        @config = args[:config]
        @region = args[:region]

        @s3 = Fog::Storage.new :provider                 => 'AWS',
                               :aws_access_key_id        => @config.access_key,
                               :aws_secret_access_key    => @config.secret_key,
                               :region                   => @region
      end

    end
  end
end