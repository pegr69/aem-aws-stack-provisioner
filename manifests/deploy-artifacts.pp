class deploy_artifacts (
  $tmp_dir,
  $descriptor_file = $::descriptor_file,
  $component       = $::component,
) {

  # load descriptor file
  $descriptor_hash = loadjson("${tmp_dir}/${descriptor_file}")
  notify { "The descriptor_hash is: ${descriptor_hash}": }

  # extract component hash
  $component_hash = $descriptor_hash[$component]
  notify { "The component_hash is: ${component_hash}": }

  if $component_hash {

    # extract the artifacts hash
    $artifacts = $component_hash['artifacts']
    notify { "The artifacts is: ${artifacts}": }

    if $artifacts {

      class { 'deploy_dispatcher_artifacts':
        artifacts => $artifacts,
        path      => "${tmp_dir}/artifacts",
      }

    } else {

      notify { "no 'artifacts' defined for component: ${component} in descriptor file: ${descriptor_file}. nothing to deploy": }

    }

    # extract the packages hash
    $packages = $component_hash['packages']
    notify { "The packages is: ${packages}": }

    if $packages {

      class { 'aem_resources::deploy_packages':
        packages => $packages,
        path     => "${tmp_dir}/packages",
      } ->
      file { "${tmp_dir}/packages":
        ensure   => absent,
        force    => true,
      }

    } else {

      notify { "no 'packages' defined for component: ${component} in descriptor file: ${descriptor_file}. nothing to deploy": }

    }


  } else {

    notify { "component: ${component} not found in descriptor file: ${descriptor_file}. nothing to deploy": }

  }

}

class deploy_dispatcher_artifacts (
  $artifacts,
  $path
) {

  # load artifacts content json file - generated by the generate-artifacts-json.py called by the download-artifacts.pp
  $artifacts_content_hash = loadjson("${path}/artifacts.json")
  notify { "The artifacts_content_hash is: ${artifacts_content_hash}": }

  # extract artifacts array
  $artifacts_array = $artifacts_content_hash['children']
  notify { "The artifacts_array is: ${artifacts_array}": }

  $artifacts.each | Integer $index, Hash $artifact| {

    $artifacts_array.each | Integer $artifact_details_index, Hash $artifact_details| {


      if $artifact_details['name'] == $artifact['name'] {


        # extract artifact_details_content array
        $artifact_details_contents = $artifact_details['children']
        notify { "The artifact_details_contents is: ${artifact_details_contents}": }


        $artifact_details_contents.each | Integer $artifact_details_content_index, Hash $artifact_details_content| {


          # if name apache-conf-templates

          if $artifact_details_content['name'] == 'apache-conf-templates' {

            $artifact_details_content['children'].each | Integer $apache_conf_template_index, Hash $apache_conf_template| {

              file { regsubst("/etc/httpd/conf/${apache_conf_template[name]}", '.epp', '', 'G'):
                ensure  => file,
                content => epp("${path}/${artifact[name]}/apache-conf-templates/${apache_conf_template[name]}"),
                owner   => 'root',
                group   => 'root',
                mode    => '0644',
                notify  => Exec['graceful restart'],
                before  => File[$path],
              }

            }

          }


          # if name virtual-hosts-templates

          if $artifact_details_content['name'] == 'virtual-hosts-templates' {

            $artifact_details_content['children'].each | Integer $virtual_host_template_index, Hash $virtual_host_template| {

              if $virtual_host_template['type'] == 'directory' {

                # create the directory in conf.d/
                file { "/etc/httpd/conf.d/${virtual_host_template[name]}":
                  ensure => directory,
                  owner  => 'root',
                  group  => 'root',
                  mode   => '0755',
                }

                $virtual_host_template['children'].each | Integer $virtual_host_site_template_index, Hash $virtual_host_site_template| {

                  file { regsubst("/etc/httpd/conf.d/${virtual_host_template[name]}/${virtual_host_site_template[name]}", '.epp', '', 'G'):
                    ensure  => file,
                    content => epp("${path}/${artifact[name]}/virtual-hosts-templates/${virtual_host_template[name]}/${virtual_host_site_template[name]}"),
                    owner   => 'root',
                    group   => 'root',
                    mode    => '0644',
                    require => File["/etc/httpd/conf.d/${virtual_host_template[name]}"],
                    notify  => Exec['graceful restart'],
                    before  => File[$path],
                  }

                }

              }
              elsif $virtual_host_template['type'] == 'file' {

                file { regsubst("/etc/httpd/conf.d/${virtual_host_template[name]}", '.epp', '', 'G'):
                  ensure  => file,
                  content => epp("${path}/${artifact[name]}/virtual-hosts-templates/${virtual_host_template[name]}"),
                  owner   => 'root',
                  group   => 'root',
                  mode    => '0644',
                  notify  => Exec['graceful restart'],
                  before  => File[$path],
                }

              }

            }

          }

          # if name dispatcher-conf-templates

          if $artifact_details_content[name] == 'dispatcher-conf-templates' {

            $artifact_details_content['children'].each | Integer $dispatcher_conf_template_index, Hash $dispatcher_conf_template| {

              file { regsubst("/etc/httpd/conf.modules.d/${dispatcher_conf_template[name]}", '.epp', '', 'G'):
                ensure  => file,
                content => epp("${path}/${artifact[name]}/dispatcher-conf-templates/${dispatcher_conf_template[name]}"),
                owner   => 'root',
                group   => 'root',
                mode    => '0644',
                notify  => Exec['graceful restart'],
                before  => File[$path],
              }

            }
          }

        }
      }
    }
  }

  exec { 'graceful restart':
    cwd         => '/usr/sbin',
    path        => '/usr/sbin',
    command     => 'apachectl -k graceful',
    refreshonly => true,
  }

  file { $path:
    ensure => absent,
    force  => true,
  }

}

include deploy_artifacts
