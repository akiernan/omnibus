#!/bin/bash
#
# Install a full Opscode Client
#

PROGNAME=$(basename $0)
INSTALLER_DIR=$(dirname $0)
PATH=/usr/sbin:/usr/bin:/sbin:/bin

function error_exit
{
	echo "${PROGNAME}: ${1:-"Unknown Error"}" 1>&2
	exit 1
}

validation_key=
organization=
chef_url=

while getopts o:u:v: opt
do
    case "$opt" in
      v)  validation_key="$OPTARG";;
      o)  organization="$OPTARG"; chef_url="https://api.opscode.com/organizations/$OPTARG";;
      u)  chef_url="$OPTARG";;
      \?)		# unknown flag
      	  echo >&2 \
            "usage: $0 [-v validation_key] ([-o organization] || [-u url]) "
	  exit 1;;
    esac
done
shift `expr $OPTIND - 1`


mkdir -p /opt/opscode || error_exit "Cannot create /opt/opscode!"
LD_LIBRARY_PATH=$INSTALLER_DIR/embedded/lib $INSTALLER_DIR/embedded/bin/rsync -a --delete --exclude /setup.sh $INSTALLER_DIR/ /opt/opscode || error_exit "Cannot rsync release to /opt/opscode"

if [ "" != "$chef_url" ]; then
  mkdir -p /etc/chef || error_exit "Cannot create /etc/chef!"
  (
  cat <<'EOP'
log_level :info
log_location STDOUT
EOP
  ) > /etc/chef/client.rb
  if [ "" != "$chef_url" ]; then
    echo "chef_server_url '${chef_url}'" >> /etc/chef/client.rb
  fi
  if [ "" != $organization ]; then
    echo "validation_client_name '${organization}-validator'" >> /etc/chef/client.rb
  fi
  chmod 644 /etc/chef/client.rb
fi

if [ "" != "$validation_key" ]; then
  cp $validation_key /etc/chef/validation.pem || error_exit "Cannot copy the validation key!"
  chmod 600 /etc/chef/validation.pem
fi

ln -sf /opt/opscode/bin/chef-client /usr/bin || error_exit "Cannot link chef-client to /usr/bin"
ln -sf /opt/opscode/bin/chef-solo /usr/bin || error_exit "Cannot link chef-solo to /usr/bin"
ln -sf /opt/opscode/bin/knife /usr/bin || error_exit "Cannot link knife to /usr/bin"
ln -sf /opt/opscode/bin/shef /usr/bin || error_exit "Cannot link shef to /usr/bin"
ln -sf /opt/opscode/bin/ohai /usr/bin || error_exit "Cannot link ohai to /usr/bin"

gemdir=`/opt/opscode/embedded/bin/gem environment gemdir`
chef_version=`/opt/opscode/bin/knife -v | awk '{print $2}'`
distro="${gemdir}/gems/chef-${chef_version}/distro"
if [ -f "/etc/debian_version" ]; then
  [ -r /etc/default/chef-client ] || cp  ${distro}/debian/etc/default/chef-client /etc/default
  chmod +x ${distro}/debian/etc/init.d/chef-client
  ln -sf ${distro}/debian/etc/init.d/chef-client /etc/init.d/chef-client
elif [ -f "/etc/redhat-release" ]; then
  [ -r /etc/sysconfig/chef-client ] || cp  ${distro}/redhat/etc/sysconfig/chef-client /etc/sysconfig
  chmod +x ${distro}/redhat/etc/init.d/chef-client
  ln -sf ${distro}/redhat/etc/init.d/chef-client /etc/rc.d/init.d/chef-client
  ln -sf ${distro}/redhat/etc/logrotate.d/chef-client /etc/logrotate.d/client
  chkconfig --add chef-client
  service chef-client condrestart
fi

echo "Thank you for installing Chef!"

exit 0
