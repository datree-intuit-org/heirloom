require 'fog'

module Heirloom
  module AWS
    class S3

      def initialize(args)
        @config = args[:config]
        @region = args[:region]
        @logger = @config.logger

        fog_args = { :region   => @region, :provider => 'AWS' }

        if @config.use_iam_profile
          fog_args[:use_iam_profile] = true
        else
          fog_args[:aws_access_key_id]     = @config.access_key
          fog_args[:aws_secret_access_key] = @config.secret_key
        end

        @s3 = Fog::Storage.new fog_args
      end

      def delete_object(bucket_name, object_name, options = {})
        @s3.delete_object(bucket_name, object_name, options)
      end

      def get_bucket(bucket)
        @s3.directories.get bucket
      end

      def bucket_exists?(bucket)
        get_bucket(bucket) != nil
      rescue Excon::Errors::Forbidden
        false
      end

      def bucket_empty?(bucket)
        get_bucket_object_versions(bucket)["Versions"].count == 0
      end

      def bucket_exists_in_another_region?(bucket)
        if bucket_exists? bucket
          get_bucket(bucket).location != @region
        else
          false
        end
      rescue Excon::Errors::Forbidden
        false
      end

      def bucket_owned_by_another_account?(bucket)
        get_bucket bucket
        false
      rescue Excon::Errors::Forbidden
        @logger.warn "#{bucket} owned by another account."
        true
      end

      def bucket_name_available?(bucket)
        @logger.info "Checking for #{bucket} availability in #{@region}."

        if bucket_owned_by_another_account?(bucket) ||
           bucket_exists_in_another_region?(bucket)
           false
        else
          true
        end
      end

      def delete_bucket(bucket)
        if bucket_empty? bucket
          @s3.delete_bucket bucket
        else
          @logger.warn "#{bucket} not empty, not destroying."
          false
        end
      rescue Excon::Errors::NotFound
        @logger.info "#{bucket} already destroyed."
        true
      end

      def get_object(bucket_name, object_name)
        @s3.get_object(bucket_name, object_name).body
      end

      def get_object_acl(args)
        @s3.get_object_acl(args[:bucket], args[:object_name]).body
      end

      def get_bucket_object_versions(bucket)
        @s3.get_bucket_object_versions(bucket).body
      end

      def put_object_acl(bucket, key, grants)
        @s3.put_object_acl(bucket, key, grants)
        true
      rescue Excon::Errors::BadRequest => e
        error = XmlSimple.xml_in e.response.body
        error['Message'].each do |msg|
          @logger.error msg
        end
        false
      end

      def put_bucket(bucket_name, region)
        region = nil if region == 'us-east-1'
        options = { 'LocationConstraint' => region,
                    'x-amz-acl'          => 'private' }
        @s3.put_bucket bucket_name, options
      end

    end
  end
end
