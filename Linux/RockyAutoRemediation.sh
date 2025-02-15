#!/bin/bash

# Ensure the script is run as root
if [[ $EUID -ne 0 ]]; then
   echo "Please run this script as root."
   exit 1
fi

# Function to check and fix permissions on the shadow file
fix_shadow_permissions() {
    echo "Fixing permissions on /etc/shadow..."
    chmod 640 /etc/shadow || echo "Failed to fix shadow permissions"
}

# Function to enable firewall
enable_firewall() {
    echo "Enabling firewall..."
    firewall-cmd --permanent --add-service=ssh || echo "Failed to enable firewall"
    firewall-cmd --reload || echo "Failed to reload firewall"
}

# Enable IPv4 TCP SYN cookies
enable_syn_cookies() {
    echo "Enabling IPv4 TCP SYN cookies..."
    sysctl -w net.ipv4.tcp_syncookies=1 || echo "Failed to enable SYN cookies"
}

# Ignore bogus ICMP errors
ignore_bogus_icmp() {
    echo "Ignoring bogus ICMP errors..."
    sysctl -w net.ipv4.icmp_ignore_bogus_error_responses=1 || echo "Failed to ignore bogus ICMP errors"
}

# Enable logging of martian packets
enable_martian_logging() {
    echo "Enabling logging of martian packets..."
    sysctl -w net.ipv4.conf.all.log_martians=1 || echo "Failed to enable martian packet logging"
}

# Disable IRC daemon
remove_irc_daemon() {
    echo "Removing IRC daemon..."
    dnf remove ircd -y || echo "Failed to remove IRC daemon"
}

# Disable Minetest service
remove_minetest_service() {
    echo "Removing Minetest service..."
    dnf remove minetest -y || echo "Failed to remove Minetest service"
}

# Update Apache
update_apache() {
    echo "Updating Apache..."
    dnf upgrade httpd -y || echo "Failed to update Apache"
}

# Update PHP
update_php() {
    echo "Updating PHP..."
    dnf upgrade php -y || echo "Failed to update PHP"
}

# Disable SSH root login
disable_ssh_root_login() {
    echo "Disabling SSH root login..."
    sed -i 's/#PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config || echo "Failed to disable SSH root login"
    systemctl restart sshd
}

# Disable unnecessary services (FTP, POP3, SMTP)
disable_services() {
     echo "Disabling FTP, POP3, and SMTP services..."
    
    # List of services to disable
    services=("vsftpd" "dovecot" "postfix" "telnetd" "rsh-server" "rlogin" "rexec" "tftp" "snmpd" "smb" "smbd" "nmbd")

    # Loop through the services and disable each one
    for service in "${services[@]}"; do
        systemctl stop "$service" || echo "Failed to stop $service"
        systemctl disable "$service" || echo "Failed to disable $service"
    done
}

# Update Sudo
update_sudo() {
    echo "Updating sudo..."
    dnf upgrade sudo -y || echo "Failed to update sudo"
}

# Enable IPv4 protection features
enable_ipv4_protection() {
    echo "Enabling IPv4 protection features..."
    sysctl -w net.ipv4.tcp_syncookies=1 || echo "Failed to enable SYN cookies"
    sysctl -w net.ipv4.icmp_echo_ignore_broadcasts=1 || echo "Failed to enable ICMP broadcast ignore"
    sysctl -w net.ipv4.conf.all.accept_redirects=0 || echo "Failed to disable ICMP redirects"
    sysctl -w net.ipv4.tcp_rfc1337=1 || echo "Failed to enable TIME-WAIT assassination protection"
}

# Restrict unprivileged access to kernel syslog
restrict_syslog_access() {
    echo "Restricting unprivileged access to kernel syslog..."
    sysctl -w kernel.dmesg_restrict=1 || echo "Failed to restrict syslog access"
}

# Fix GRUB configuration permissions
fix_grub_permissions() {
    echo "Fixing GRUB configuration permissions..."
    chmod 600 /boot/grub2/grub.cfg || echo "Failed to fix GRUB permissions"
}

# Apply all security updates
apply_security_updates() {
    echo "Applying security updates..."
    dnf upgrade --security -y || echo "Failed to apply security updates"
}

# Disable Samba SMB1 protocol and require encryption
harden_samba() {
    echo "Hardening Samba configuration..."
    echo "server min protocol = SMB2" >> /etc/samba/smb.conf || echo "Failed to disable SMB1"
    echo "smb encrypt = required" >> /etc/samba/smb.conf || echo "Failed to require Samba encryption"
    systemctl restart smbd
}

# Remove banned file types from users folders
remove_banned_files() {
   # Define file extensions to search for
   FILE_EXTENSIONS=("*.mp3")
   
   # Loop through each user's home directory
   for user_home in /home/*; do
       # Check if the directory exists and is a directory (exclude non-directories)
       if [ -d "$user_home" ]; then
           # Loop through each file extension
           for ext in "${FILE_EXTENSIONS[@]}"; do
               # Search for the files recursively in the user's home directory and remove them
               if find "$user_home" -type f -name "$ext" | grep -q .; then
                   find "$user_home" -type f -name "$ext" -exec rm -f {} \;
                   echo "Removed $ext files from $user_home."
               else
                   echo "No $ext files found in $user_home."
               fi
           done
       fi
   done
}

# Update password policies
update_password_policies() {
   echo "Configuring SSH to not permit empty passwords..."
   
   if grep -q '^PermitEmptyPasswords' /etc/ssh/sshd_config; then
       sed -i 's/^PermitEmptyPasswords.*/PermitEmptyPasswords no/' /etc/ssh/sshd_config
   else
       echo 'PermitEmptyPasswords no' >> /etc/ssh/sshd_config
   fi
   
   # Restart SSH service
   systemctl restart sshd
   
   echo "Configuring password expiration policies..."
   sed -i 's/^PASS_MAX_DAYS.*/PASS_MAX_DAYS   90/' /etc/login.defs
   sed -i 's/^PASS_MIN_DAYS.*/PASS_MIN_DAYS   10/' /etc/login.defs
   sed -i 's/^PASS_WARN_AGE.*/PASS_WARN_AGE   7/' /etc/login.defs

   echo "Enforcing strong password policies..."
   dnf install -y pam_pwquality || echo "Failed to install pam_pwquality"
   sed -i '/pam_pwquality.so/ s/retry=3 minlen=8 difok=3/retry=3 minlen=12 difok=3 ucredit=-1 lcredit=-1 dcredit=-1 ocredit=-1/' /etc/pam.d/system-auth || echo "Failed to update password policy"
}

# Function to disable IPv4 forwarding
disable_ipv4_forwarding() {
    echo "Disabling IPv4 forwarding..."

    if grep -q '^net.ipv4.ip_forward=' /etc/sysctl.conf; then
        sed -i 's/^net.ipv4.ip_forward=.*/net.ipv4.ip_forward=0/' /etc/sysctl.conf
    else
        echo 'net.ipv4.ip_forward=0' >> /etc/sysctl.conf
    fi

    # Apply the changes
    sysctl -p
    echo "IPv4 forwarding disabled."
}

# Function to install and configure Fail2Ban
install_fail2ban() {
    echo "Installing Fail2Ban to prevent brute-force attacks..."
    dnf install fail2ban -y
    systemctl enable fail2ban
    systemctl start fail2ban
    echo "Fail2Ban installed and running."
}

# Function to set up system auditing with auditd
setup_auditd() {
    echo "Setting up system auditing with auditd..."
    dnf install audit audit-libs audispd-plugins -y
    systemctl enable auditd
    systemctl start auditd
    echo "auditd installed and running."
}

# Function to harden Chromium browser
harden_chromium() {
    echo "Configuring Chromium to apply security policies..."
    mkdir -p /etc/chromium/policies/managed/

    # Block pop-ups
    echo '{
        "DefaultPopupsSetting": 2
    }' > /etc/chromium/policies/managed/block_popups.json

    echo "Configured Chromium to block pop-ups via policy."

    # Disable Flash
    echo '{
        "PluginsAllowedForUrls": [],
        "PluginsBlockedForUrls": ["*"]
    }' > /etc/chromium/policies/managed/disable_flash.json

    echo "Disabled Flash in Chromium via policy."
   
    # Block third-party cookies
    echo '{
        "BlockThirdPartyCookies": true
    }' > /etc/chromium/policies/managed/block_third_party_cookies.json

    echo "Blocked third-party cookies in Chromium via policy."
   
    # Enable Safe Browsing
    echo '{
        "SafeBrowsingProtectionLevel": 1
    }' > /etc/chromium/policies/managed/enable_safe_browsing.json

    echo "Enabled Safe Browsing in Chromium via policy."

    # Disable password manager
    echo '{
        "PasswordManagerEnabled": false
    }' > /etc/chromium/policies/managed/disable_password_manager.json

    echo "Disabled password manager in Chromium via policy."

    # Enable automatic updates
    echo '{
        "AutoUpdateEnabled": true
    }' > /etc/chromium/policies/managed/auto_update.json

    echo "Enabled automatic updates for Chromium via policy."

    echo "Security configurations for Chromium have been applied."
}

# Function to harden Firefox browser
harden_firefox() {
    echo "Configuring Firefox to block pop-ups, disable telemetry, and apply other security settings..."
    mkdir -p /etc/firefox/policies/
   
    echo '{
        "policies": {
            "DisableTelemetry": true,
            "DisableFirefoxStudies": true,
            "BlockPopups": true,
            "Cookies": {
                "Default": {
                    "AcceptThirdParty": "never"
                }
            },
            "DisablePasswordManager": true,
            "EnableTrackingProtection": true,
            "ExtensionUpdate": true,
            "AppAutoUpdate": true
        }
    }' > /etc/firefox/policies/policies.json
   
    echo "Configured Firefox with the following settings:"
    echo "- Disabled telemetry and Firefox studies"
    echo "- Blocked pop-ups"
    echo "- Blocked third-party cookies"
    echo "- Disabled password manager"
    echo "- Enabled Enhanced Tracking Protection"
    echo "- Enabled automatic extension and browser updates"
   
    echo "Security configurations for Firefox have been applied."
}

# Function to remove unauthorized users and fix sudo privileges
remove_bad_users_fix_sudo_privs() {
    # Define authorized and sudo/root allowed users
    AUTHORIZED_USERS=("blue" "green" "brown" "purple" "orange" "lime" "yellow" "black" "cyan" "red" "white" "pink")
   
    # Add normally authorized system accounts (built-in users)
    SYSTEM_USERS=("fwupd-refresh" "hplip" "dnsmasq" "sssd" "pulse" "flatpak" "_flatpak mail spool" "_flatpak" "saned" "colord" "root" "syslog" "_apt" "tss" \
    "rtkit" "kernoops" "uuidd" "cups-pk-helper" "lightdm" "tcpdump" "ftp" "speech-dispatcher" "avahi-autoipd" \
    "nm-openvpn" "geoclue" "messagebus" "sshd" "daemon" "bin" "postfix" "rpc" "rpcuser" "dbus" "ntp" "saslauth" "chrony" \
    "usbmux" "polkitd" "avahi" "systemd-journal" "mysql" "systemd-coredump" "sys" "sync" "games" "man" "lp" "mail" \
    "news" "uucp" "proxy" "www-data" "backup" "list" "irc" "gnats" "nobody" "systemd-timesync" "systemd-network" \
    "systemd-resolve" "systemd-bus-proxy" "gdm" "systemd-oom" "ntpd" "openvpn" "clamav" "nscd" "docker" "libvirt" \
    "pulse-access" "Debian-tor" "chrony" "tss" "plex" "snmp" "lxd" "mysql" "postgres" "oracle" "mssql" "db2inst1" "db2fenc1" \
    "adm" "shutdown" "halt" "operator" "pipewire" "setroubleshoot" "gnome-initial-setup")
   
    # Define sudo/root allowed users
    SUDO_ALLOWED_USERS=("root" "cyan" "red" "white" "pink")
   
    # Get current users from the system
    CURRENT_USERS=$(cut -d: -f1 /etc/passwd)
   
    # Function to remove unauthorized sudo/root privileges
    remove_sudo_privileges() {
        local user=$1
        if groups "$user" | grep -qE '\bsudo\b|\broot\b'; then
            deluser "$user" sudo
            deluser "$user" root
            echo "Removed sudo/root privileges from user $user."
        fi
    }
   
    # Merge authorized users and system users to form a complete list
    FULL_AUTHORIZED_USERS=("${AUTHORIZED_USERS[@]}" "${SYSTEM_USERS[@]}")
   
    # Collect unauthorized users for review
    UNAUTHORIZED_USERS=()
   
    # Find users not in the authorized list
    for user in $CURRENT_USERS; do
        if [[ ! " ${FULL_AUTHORIZED_USERS[@]} " =~ " ${user} " ]]; then
            UNAUTHORIZED_USERS+=("$user")
        fi
    done
   
    # If there are unauthorized users, ask for confirmation
    if [ ${#UNAUTHORIZED_USERS[@]} -gt 0 ]; then
        echo "The following users will be removed:"
        for user in "${UNAUTHORIZED_USERS[@]}"; do
            echo "$user"
        done
        echo "Is this okay? Warning: this operation cannot be undone. Make sure you google the user before pressing yes to ensure it's not a system user."
        read -p "Type 'yes' to proceed: " confirmation
   
        if [[ $confirmation == "yes" ]]; then
            # Proceed with removing unauthorized users
            for user in "${UNAUTHORIZED_USERS[@]}"; do
                echo "User $user is not authorized. Deleting user..."
                userdel -r "$user"
            done
        else
            echo "Operation canceled. No users were removed."
            exit 1
        fi
    else
        echo "No unauthorized users to remove."
    fi
   
    # Check users with sudo or root privileges
    for user in $CURRENT_USERS; do
        if groups "$user" | grep -qE '\bsudo\b|\broot\b'; then
            if [[ ! " ${SUDO_ALLOWED_USERS[@]} " =~ " ${user} " ]]; then
                echo "User $user is not allowed sudo/root privileges. Removing privileges..."
                remove_sudo_privileges "$user"
            else
                echo "User $user is allowed sudo/root privileges."
            fi
        fi
    done
}

# Main execution
fix_shadow_permissions
enable_firewall
enable_syn_cookies
ignore_bogus_icmp
enable_martian_logging
remove_irc_daemon
remove_minetest_service
update_apache
update_php
disable_ssh_root_login
disable_services
update_sudo
enable_ipv4_protection
restrict_syslog_access
fix_grub_permissions
apply_security_updates
harden_samba
remove_banned_files
update_password_policies
disable_ipv4_forwarding
install_fail2ban
setup_auditd
harden_chromium
harden_firefox
remove_bad_users_fix_sudo_privs

echo "Rocky Linux security remediation script complete."
