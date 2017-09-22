require 'safe_yaml'
require 'chef/mash'
require 'chef/mixin/deep_merge'
require_relative './path_helper'
require_relative './database_helper'
require_relative './service_helper'

SafeYAML::OPTIONS[:default_mode] = :safe


class Psych::Visitors::YAMLTree

    # We want everything to be sorted
    def visit_Hash(o)
        tag      = o.class == ::Hash ? nil : "!ruby/hash:#{o.class}"
        implicit = !tag

        register(o, @emitter.start_mapping(nil, tag, implicit, Psych::Nodes::Mapping::BLOCK))

        o.keys.sort.each do |k|  # This line is changed.
            accept k
            accept o[k]
        end

        @emitter.end_mapping
    end

end


TOP_MESSAGE = '
#####################################################################################################
# IMPORTANT WARNING                                                                                 #
# This file is auto-generated by the `/opt/scalr-server/bin/scalr-server-ctl reconfigure` command.  #
#                                                                                                   #
# DO NOT EDIT THIS FILE MANUALLY.                                                                   #
#  + Your changes would be lost after an upgrade.                                                   #
#  + Several daemons need to be restarted after making changes to the configuration file.           #
#                                                                                                   #
# For more information, view: https://scalr-wiki.atlassian.net/wiki/x/RgAeAQ                        #
#                                                                                                   #
#####################################################################################################
'

module Scalr
    module ConfigHelper
        include Scalr::PathHelper
        include Scalr::DatabaseHelper
        include Scalr::ServiceHelper

        def dump_scalr_configuration(node)

            scalr_conn_details = mysql_scalr_params(node).merge({
                :user => node[:scalr_server][:mysql][:scalr_user],
                :pass => node[:scalr_server][:mysql][:scalr_password],
                :name => node[:scalr_server][:mysql][:scalr_dbname],
            })
            scalr_conn_details.delete(:username)
            scalr_conn_details.delete(:password)

            analytics_conn_details = mysql_analytics_params(node).merge({
                :user => node[:scalr_server][:mysql][:scalr_user],
                :pass => node[:scalr_server][:mysql][:scalr_password],
                :name => node[:scalr_server][:mysql][:analytics_dbname],
            })
            analytics_conn_details.delete(:username)
            analytics_conn_details.delete(:password)

            cron_services = {}
            enabled_services(node, :php).each { |svc|
                cron_services[svc[:name]] = svc[:service_config].merge({
                    :log => "#{log_dir_for node, 'service'}/php-#{svc[:name]}.log",
                    :enabled => true
                })
            }

            # Actual configuration generated here.
            config = {
                :scalr => {
                    :csg => {
                        :enabled => node[:scalr_server][:csg][:enable],
                        :mysql => scalr_conn_details.clone,
                        :endpoint => {
                            :host => node[:scalr_server][:csg][:bind_host],
                            :port => node[:scalr_server][:csg][:bind_port]
                        }
                    },

                    :connections => {
                        :mysql => scalr_conn_details.clone  # Ruby wants to use '1' as an alias, and PHP doesn't accept it..
                    },

                    :analytics => {
                        :enabled => true,
                        :connections => {
                            :analytics => analytics_conn_details.clone,
                            :scalr => scalr_conn_details.clone,
                        },
                        :poller => {
                            :cryptokey => "#{scalr_bundle_path node}/app/etc/.cryptokey"
                        }
                    },

                    :email => {
                        :address => node[:scalr_server][:app][:email_from_address],
                        :name => node[:scalr_server][:app][:email_from_name],
                    },

                    :auth_mode => 'scalr',
                    :instances_connection_policy => node[:scalr_server][:app][:instances_connection_policy],

                    :system => {
                        :default_disable_firewall_management => false,
                        :instances_connection_timeout => 4,
                        :server_terminate_timeout => '+3 minutes',
                        :scripting => {
                            :logs_storage => 'instance',
                            :default_instance_log_rotation_period => 36000,
                            :default_abort_init_on_script_fail => 1,
                        },
                    },

                    :endpoint => {
                        :scheme => node[:scalr_server][:routing][:endpoint_scheme],
                        :host => node[:scalr_server][:routing][:endpoint_host],
                    },

                    :aws => {
                        :ip_pool => node[:scalr_server][:app][:ip_ranges],
                        :security_group_name => "scalr.#{node[:scalr_server][:app][:id]}.ip-pool",
                    },

                    :billing => { :enabled => false },

                    :dns => {
                        :mysql => scalr_conn_details.clone,
                        :static => {
                            :enabled => false,
                            :nameservers => %w(ns1.example-dns.net ns2.example-dns.net),
                            :domain_name => 'example-dns.net',
                        },
                        :global => {
                            :enabled => false,
                            :nameservers => %w(ns1.example.net ns2.example.net ns3.example.net ns4.example.net),
                            :default_domain_name => 'provide.domain.here.in'
                        },
                    },


                    :load_statistics => {
                        :connections => {
                            :plotter => {
                                :scheme => plotter_scheme(node),
                                :host => plotter_host(node),
                                :port => plotter_port(node),
                                :bind_scheme => node[:scalr_server][:service][:plotter_bind_scheme],
                                :bind_host => node[:scalr_server][:service][:plotter_bind_host],
                                :bind_port => node[:scalr_server][:service][:plotter_bind_port],
                                # Deprecated
                                :bind_address => node[:scalr_server][:service][:plotter_bind_host],
                            },
                        },
                        :rrd =>{
                            :dir => data_dir_for(node, 'rrd'),
                            :run_dir => run_dir_for(node, 'rrd'),
                            :rrdcached_sock_path => "#{run_dir_for node, 'rrd'}/rrdcached.sock",
                        },
                        :img => {
                            :scheme => graphics_scheme(node),
                            :host => graphics_host(node),
                            :path => node[:scalr_server][:routing][:graphics_path],
                            :dir => "#{data_dir_for node, 'service'}/graphics"
                        }
                    },

                    :crontab => {
                        :services => cron_services
                    },

                    :workflow_engine => {
                        :celery => {
                            :broker_url => "amqp://#{node[:scalr_server][:rabbitmq][:scalr_user]}" \
                                           ":#{node[:scalr_server][:rabbitmq][:scalr_password]}" \
                                           "@#{node[:scalr_server][:app][:rabbitmq_host]}" \
                                           ":#{node[:scalr_server][:rabbitmq][:bind_port]}",
                            :broker_use_ssl => true,
                        },
                        :rabbitmq => {
                            :public_host => "amqp://#{node[:scalr_server][:rabbitmq][:scalr_user]}" \
                                            ":#{node[:scalr_server][:rabbitmq][:scalr_password]}" \
                                            "@#{node[:scalr_server][:routing][:endpoint_host]}" \
                                            ":#{node[:scalr_server][:rabbitmq][:bind_port]}",
                            :api_url => "https://#{node[:scalr_server][:rabbitmq][:scalr_user]}" \
                                        ":#{node[:scalr_server][:rabbitmq][:scalr_password]}" \
                                        "@#{node[:scalr_server][:app][:rabbitmq_host]}" \
                                        ":#{node[:scalr_server][:rabbitmq][:mgmt_bind_port]}/api",
                            :ssl_verify => true,
                            :ssl_cacert => node[:scalr_server][:rabbitmq][:ssl_cert_path],
                        }
                    },

                    :ui => {
                        :mindterm_enabled => true
                    },

                    :scalarizr_update => {
                        :mode => 'client',
                        :default_repo => 'stable',
                        :repos => {
                            :stable => {
                                :deb_repo_url => 'http://repo.scalr.net/apt-plain stable/',
                                :rpm_repo_url => 'http://repo.scalr.net/rpm/stable/rhel/$releasever/$basearch',
                                :win_repo_url => 'http://repo.scalr.net/win/stable',
                                :docker_repo_url => 'docker.io/scalr/scalarizr-stable',
                            },
                            :latest => {
                                :deb_repo_url => 'http://repo.scalr.net/apt-plain latest/',
                                :rpm_repo_url => 'http://repo.scalr.net/rpm/latest/rhel/$releasever/$basearch',
                                :win_repo_url => 'http://repo.scalr.net/win/latest',
                                :docker_repo_url => 'docker.io/scalr/scalarizr-latest',
                            },
                        }
                    }
                }
            }

            # Using Mashes ships with Chef... And they stringify all the keys for us, which is great because it lets
            # us ensure that:
            # - Our keys are readable by PHP and Python (symbols aren't).
            # - Our merge applies properly regardless of whether we used symbols or strings.
            config = ::Mash.new config

            # Prepare our override config
            extra_config = node[:scalr_server][:app][:configuration]
            unless extra_config.nil?
                # We use hash_only_merge because we want to let the user override any configuration key they don't like,
                # including arrays.
                # Note that a regular deep_merge wouldn't work anyway, because it could result in us modifying
                # items that are ultimately attributes (such as the ip_pool array).
                ::Chef::Mixin::DeepMerge.hash_only_merge! config, Mash.new(extra_config)
            end

            # The double dump / load stage is here to convert everything to "plain" objects that can then be loaded
            # by PHP / Python (because Chef attributes are *not* plain objects).
            TOP_MESSAGE + YAML.dump(SafeYAML.load(YAML.dump(config)))
        end

    end
end
