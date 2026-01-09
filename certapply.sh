#!/bin/bash

# ==========================================
# ACME.SH 手动DNS模式 交互式管理脚本 v1.1
# ==========================================

# 颜色定义
RED='\033[31m'
GREEN='\033[32m'
YELLOW='\033[33m'
CYAN='\033[36m'
BLUE='\033[34m'
PLAIN='\033[0m'

# ACME.SH 路径检查
ACME_SCRIPT="$HOME/.acme.sh/acme.sh"

if [ ! -f "$ACME_SCRIPT" ]; then
    echo -e "${RED}错误: 未在 $ACME_SCRIPT 找到 acme.sh。${PLAIN}"
    echo -e "请先安装 acme.sh: curl https://get.acme.sh | sh"
    exit 1
fi

# 封装 acme.sh 调用
acme() {
    "$ACME_SCRIPT" "$@"
}

# --- 辅助函数：输入处理 ---
get_input() {
    local prompt="$1"
    local var_name="$2"
    local input_val

    echo -e "${CYAN}${prompt}${PLAIN} (输入 q 退出): "
    read -r input_val
    
    if [[ "$input_val" == "q" || "$input_val" == "Q" ]]; then
        echo -e "${YELLOW}操作已取消，返回主菜单...${PLAIN}"
        return 1
    fi
    
    if [[ -z "$input_val" ]]; then
         echo -e "${RED}输入不能为空，请重新操作。${PLAIN}"
         return 1
    fi

    eval $var_name="'$input_val'"
    return 0
}

# --- 功能模块 ---

# 1. 设置邮箱
func_set_email() {
    local email
    if get_input "请输入用于注册的邮箱地址" email; then
        echo -e "${GREEN}正在注册账户...${PLAIN}"
        acme --register-account -m "$email"
        echo -e "${GREEN}操作完成。${PLAIN}"
    fi
    read -n 1 -s -r -p "按任意键继续..."
}

# 2. 切换 CA
func_set_ca() {
    echo -e "请选择默认 CA 机构:"
    echo -e "1. Let's Encrypt (推荐)"
    echo -e "2. ZeroSSL"
    echo -e "3. Google Public CA"
    
    local choice
    if get_input "请输入选项 (1-3)" choice; then
        case "$choice" in
            1) acme --set-default-ca --server letsencrypt ;;
            2) acme --set-default-ca --server zerossl ;;
            3) acme --set-default-ca --server google ;;
            *) echo -e "${RED}无效选项${PLAIN}" ;;
        esac
    fi
    read -n 1 -s -r -p "按任意键继续..."
}

# 3. 查看证书列表
func_list_certs() {
    echo -e "${GREEN}当前证书列表：${PLAIN}"
    acme --list
    echo -e ""
    read -n 1 -s -r -p "按任意键继续..."
}

# 4. 手动申请 (获取 TXT)
func_issue_step1() {
    echo -e "${YELLOW}--- 步骤 1: 获取 DNS 解析记录 ---${PLAIN}"
    echo -e "提示: 如果是泛域名(如 *.a.com)，请直接输入 *.a.com"
    
    local domain
    if get_input "请输入要申请的域名" domain; then
        echo -e "${GREEN}正在请求证书服务器生成 TXT 记录...${PLAIN}"
        echo -e "${BLUE}命令执行中，请稍候...${PLAIN}"
        
        acme --issue --dns -d "$domain" --yes-I-know-dns-manual-mode-enough-go-ahead-please
        
        echo -e "\n${YELLOW}================ 注意 ================${PLAIN}"
        echo -e "请查看上方输出的 ${GREEN}TXT value${PLAIN} 和 ${GREEN}Domain${PLAIN}。"
        echo -e "请前往你的域名服务商添加/修改对应的 TXT 记录。"
        echo -e "添加完成后，请使用菜单选项 [5] 检测，然后用 [6] 完成签发。"
        echo -e "${YELLOW}======================================${PLAIN}"
    fi
    read -n 1 -s -r -p "按任意键继续..."
}

# 5. 查询 DNS (nslookup)
func_check_dns() {
    echo -e "${YELLOW}--- DNS 生效检测工具 ---${PLAIN}"
    local domain
    if get_input "请输入刚才申请的域名 (例如 example.com)" domain; then
        local check_domain="${domain/\*./}"
        local target="_acme-challenge.$check_domain"
        
        echo -e "${GREEN}正在查询 TXT 记录: $target ...${PLAIN}"
        nslookup -q=txt "$target"
        
        echo -e "\n${CYAN}判断依据：${PLAIN}"
        echo -e "如果上方 'text =' 后面显示了由 acme.sh 生成的字符串，说明DNS已生效。"
        echo -e "如果没有显示或显示 NXDOMAIN，请等待几分钟再试。"
    fi
    read -n 1 -s -r -p "按任意键继续..."
}

# 6. 验证并签发 (更新)
func_renew_step2() {
    echo -e "${YELLOW}--- 步骤 2: 验证 DNS 并签发/更新证书 ---${PLAIN}"
    echo -e "确保你已经添加了 TXT 记录并能通过选项 [5] 查到。"
    
    local domain
    if get_input "请输入域名" domain; then
        echo -e "${GREEN}正在验证并签发证书...${PLAIN}"
        
        acme --renew -d "$domain" --yes-I-know-dns-manual-mode-enough-go-ahead-please
        
        echo -e "\n${GREEN}如果显示 Cert success，证书已生成在 ~/.acme.sh/${domain}/ 目录下。${PLAIN}"
        echo -e "接下来请自行使用 --install-cert 命令部署到 Nginx/Apache。"
    fi
    read -n 1 -s -r -p "按任意键继续..."
}

# 7. 强制验证并签发 (新增功能)
func_renew_force() {
    echo -e "${RED}================= ⚠️ 高危操作警告 ⚠️ =================${PLAIN}"
    echo -e "${YELLOW}你选择了强制更新模式 (--force)。${PLAIN}"
    echo -e "1. 这将忽略证书有效期，强制重新申请。"
    echo -e "2. 在手动DNS模式下，这通常会生成 ${RED}新的 TXT 验证值${PLAIN}。"
    echo -e "3. 这意味着你之前添加的 TXT 记录将失效，你必须去DNS服务商处 ${RED}再次修改${PLAIN} 记录。"
    echo -e "4. 只有在标准更新(选项6)反复失败，或者你需要重置申请流程时才使用此选项。"
    echo -e "${RED}======================================================${PLAIN}"

    read -p "我已知晓风险，确认要继续吗？(请输入 y 并回车): " confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        echo -e "${GREEN}已取消操作，返回主菜单。${PLAIN}"
        return
    fi

    local domain
    if get_input "请输入域名" domain; then
        echo -e "${GREEN}正在强制请求新证书 (这可能会生成新的TXT记录)...${PLAIN}"
        
        acme --renew -d "$domain" --yes-I-know-dns-manual-mode-enough-go-ahead-please --force
        
        echo -e "\n${YELLOW}提示：${PLAIN}"
        echo -e "如果上方输出了 'Add the following TXT record'，请务必去修改 DNS 记录。"
        echo -e "修改后，等待生效，然后再次运行选项 [6] (标准验证) 即可。"
    fi
    read -n 1 -s -r -p "按任意键继续..."
}

# 8. 移除证书 (原选项7)
func_remove_cert() {
    echo -e "${RED}警告: 这将停止证书的续期任务并移除配置 (不会删除已签发的证书文件)。${PLAIN}"
    local domain
    if get_input "请输入要移除的域名" domain; then
        acme --remove -d "$domain"
        echo -e "${GREEN}已从列表中移除 $domain ${PLAIN}"
        echo -e "建议手动删除文件夹: rm -rf ~/.acme.sh/$domain"
    fi
    read -n 1 -s -r -p "按任意键继续..."
}

# --- 主菜单 ---
show_menu() {
    clear
    echo -e "${BLUE}#############################################${PLAIN}"
    echo -e "${BLUE}#       ACME.SH 手动 DNS 模式管理助手       #${PLAIN}"
    echo -e "${BLUE}#############################################${PLAIN}"
    echo -e ""
    echo -e "${GREEN}1.${PLAIN} 设置注册邮箱 (第一次使用必选)"
    echo -e "${GREEN}2.${PLAIN} 切换默认 CA (建议切换为 Let's Encrypt)"
    echo -e "${GREEN}3.${PLAIN} 查看证书列表"
    echo -e "---------------------------------------------"
    echo -e "${YELLOW}4.${PLAIN} 申请新证书 [步骤1: 获取 TXT 记录]"
    echo -e "${YELLOW}5.${PLAIN} 查询 DNS 是否生效 (nslookup)"
    echo -e "${YELLOW}6.${PLAIN} 验证并签发/更新证书 [步骤2: 完成申请]"
    echo -e "${RED}7. (强制) 验证并签发/更新证书 [慎用]${PLAIN}"
    echo -e "---------------------------------------------"
    echo -e "${RED}8.${PLAIN} 移除/停止管理证书"
    echo -e "${GREEN}0.${PLAIN} 退出脚本"
    echo -e ""
    echo -e "提示: 输入 q 可中途取消输入"
    echo -e ""
}

# --- 主逻辑循环 ---
while true; do
    show_menu
    read -p "请输入选项 [0-8]: " choice
    
    case "$choice" in
        1) func_set_email ;;
        2) func_set_ca ;;
        3) func_list_certs ;;
        4) func_issue_step1 ;;
        5) func_check_dns ;;
        6) func_renew_step2 ;;
        7) func_renew_force ;;  # 新增
        8) func_remove_cert ;;  # 顺延
        0|q|Q) 
            echo -e "${GREEN}再见！${PLAIN}"
            exit 0 
            ;;
        *) 
            echo -e "${RED}无效输入，请重试。${PLAIN}"
            sleep 1
            ;;
    esac
done