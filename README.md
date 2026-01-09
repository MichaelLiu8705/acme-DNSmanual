# acme-DNSmanual
Apply for the domain name certificate through the manual DNS mode of acme.sh

这个脚本是利用热门脚本[acmesh-official/acme.sh](https://github.com/acmesh-official/acme.sh)的DNS手动模式申请证书，适用于API模式申请证书失败，想自己手动申请let encrypt证书的情形。
使用方法：
1. 下载`certapply.sh`;
2. 把脚本放到linux服务器;
3. `chmod +x ./certapply.sh && bash ./certapply.sh`          
4. 输入1设置注册人邮箱（到期时会邮件提醒）；
5. 输入2设置默认CA提供商（建议选择let encrypt，可以申请*.example.com这种格式的泛域名证书）；
6. 输入4申请新证书
7. 按照说明去自己的DNS解析服务商处添加TXT解析记录，等待10-20min；
8. 使用5查询DNS是否生效（如果申请的是泛域名证书，输入example.com即可，不需要*.example.com），也可以自己在某些站长工具查询，或者使用其他电脑使用`nslookup -type=txt [域名] 223.5.5.5`进行查询；
9. 查询成功之后，使用6签发证书。
10. 之后在~/.acme.sh/下寻找自己域名对应的文件夹，下载域名证书即可。
