# cloudflare-api-v4-ddns
cloudflare 一键 ddns 脚本 (大陆可用)  
下载`cf-v4-ddns.sh`编辑一下加到crontab里就完事了  
```
sudo wget https://raw.githubusercontent.com/zanjie1999/cloudflare-api-v4-ddns/master/cf-v4-ddns.sh -O /usr/local/bin/cf-ddns.sh
sudo chmod +x /usr/local/bin/cf-ddns.sh
sudo nano /usr/local/bin/cf-ddns.sh
```  
修改`default config`下的几个配置变量  
[其中CFTOKEN填的是API Token，中文叫API令牌，别填了下面的API Key](https://dash.cloudflare.com/profile/api-tokens)  
`crontab -e`  
在最后加上`*/2 * * * * /usr/local/bin/cf-ddns.sh >/dev/null 2>&1`  
如果需要日志就换成这条`*/2 * * * * /usr/local/bin/cf-ddns.sh >> /var/log/cf-ddns.log 2>&1`  
