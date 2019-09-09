import jenkins.*
import jenkins.model.*
import hudson.*
import hudson.model.*
import com.sonyericsson.hudson.plugins.gerrit.trigger.config.Config
import com.sonyericsson.hudson.plugins.gerrit.trigger.GerritServer
import com.sonyericsson.hudson.plugins.gerrit.trigger.PluginImpl


def gerrit_server_name = 'gerrit.akraino.org'
def gerrit_hostname = 'gerrit.akraino.org'
def gerrit_key_path = '/var/lib/jenkins/.ssh/gerrit.key'
def gerrit_url = 'https://gerrit.akraino.org/'
def gerrit_username = 'icn.jenkins'

if (PluginImpl.getInstance().getServer(gerrit_server_name) == null) {
  GerritServer defaultServer = new GerritServer(gerrit_server_name)
  Config config = defaultServer.getConfig()
  PluginImpl.getInstance().addServer(defaultServer)
  defaultServer.start()
  // setting properties
  config.setGerritHostName(gerrit_hostname)
  config.setGerritFrontEndURL(gerrit_url)
  config.setGerritUserName(gerrit_username)
  config.setGerritAuthKeyFile(new File(gerrit_key_path))
} else {
  Config config = PluginImpl.getInstance().getServer(gerrit_server_name).getConfig()
  config.setGerritHostName(gerrit_hostname)
  config.setGerritFrontEndURL(gerrit_url)
  config.setGerritUserName(gerrit_username)
  config.setGerritAuthKeyFile(new File(gerrit_key_path))
  PluginImpl.getInstance().save()
}
return "success"
