#!/bin/bash

function install_package {
    for package in $@; do
        dpkg -s $package &>/dev/null
        if [ $? -ne 0 ]; then
            echo "$package package not found. Installing... "
            apt-get install -y $package >/dev/null
        else
            echo "$package package is installed"
        fi
    done
}

function configure_package {
    for package in $@; do
        install_package $package
        if [ $package = "samba" ]; then
            cat >/etc/samba/smb.conf <<'EOF'
[global]
        dos charset = cp866
        server string = Samba Server
        unix charset = UTF8
        log file = /var/log/samba/%m.log
        max log size = 50
        disable spoolss = Yes
        load printers = No
        printcap name = /dev/null
        show add printer wizard = No
        unix extensions = No
        map to guest = Bad User
        security = USER
        dns proxy = No
        idmap config * : backend = tdb
        wide links = Yes


[media]
        comment = Media Folder
        path = /mediasource
        locking = No
        read only = No
        valid users = guest
EOF
            echo "$package package successfully configured"
        elif [ $package = "x11vnc" ]; then
            cat >/lib/systemd/system/x11vnc.service <<'EOF'
[Unit]
Description=Start x11vnc at startup.
After=multi-user.target

[Service]
Type=simple
ExecStart=/usr/bin/x11vnc -auth guess -forever -loop -noxdamage -repeat -rfbauth /etc/x11vnc.pass -rfbport 5900 -shared

[Install]
WantedBy=multi-user.target
EOF
            systemctl daemon-reload
            echo "$package package successfully configured"
        elif [ $package = "novnc" ]; then
            cat >/lib/systemd/system/novnc.service <<'EOF'
[Unit]
Description=NoVNC
After=network.target

[Service]
Type=simple
User=novnc
WorkingDirectory=/usr/share/novnc
ExecStart=/usr/bin/websockify --web /usr/share/novnc/ :6080 127.0.0.1:5900
#ExecStart=/usr/share/novnc/utils/launch.sh
Restart=on-abort

[Install]
WantedBy=multi-user.target
EOF
            systemctl daemon-reload
            echo "$package package successfully configured"
        elif [ $package = "openbox" ]; then
            mkdir -p /home/live/.config/openbox
            cat >/home/live/.config/openbox/autostart <<'EOF'
#!/bin/bash
export DISPLAY=:0.0
xset dpms force on
xset -dpms
xset s off
/usr/bin/mediaplayer

EOF
            chown live:live /home/live/.config/openbox
            chown live:live /home/live/.config/openbox/autostart
            cat >/home/live/.xinitrc <<'EOF'
/usr/bin/xrdb -merge .Xresources
exec openbox-session
EOF
            chown live:live /home/live/.xinitrc
            echo "$package package successfully configured"
        elif [ $package = "blackbox" ]; then
            cat >/home/live/.xinitrc <<'EOF'
/usr/bin/xrdb -merge .Xresources
export DISPLAY=:0.0
xset dpms force on
xset -dpms
xset s off
/usr/bin/mediaplayer &
exec /usr/bin/blackbox
EOF
            chown live:live /home/live/.xinitrc
            echo "$package package successfully configured"
        fi
    done
}

echo "samba-common    samba-common/dhcp       boolean false" | debconf-set-selections

configure_package vlc inotify-tools samba x11vnc novnc openbox

cat >/mediaplayer.config <<'EOF'
root_password=P1ayMyVide0
user_password=P1ayMyVide0
x11vnc_password=P1ayMyVide0
samba_password=P1ayMyVide0
vlc_password=P1ayMyVide0
nextcloud_password=P1ayMyVide0
media_source="/mediasource"
playing_source="/playingsource"
local_source="/localsource"
local_source_label="LOCALSOURCE"
vlc_name=cvlc
vlc_options=" -f -R --no-video-title --extraintf=http --http-password $vlc_password"
user_name=live
play_pause=1

EOF
cat >/usr/bin/mediaplayer <<'EOF'
#!/bin/bash
if [ -f /run/initramfs/memory/toram/mediaplayer.config ]; then
    . /run/initramfs/memory/toram/mediaplayer.config
    cp /run/initramfs/memory/toram/mediaplayer.config /mediaplayer.config
elif [ -f /run/initramfs/memory/data/minios/mediaplayer.config ]; then
    . /run/initramfs/memory/data/minios/mediaplayer.config
    cp /run/initramfs/memory/data/minios/mediaplayer.config /mediaplayer.config
else
    . /mediaplayer.config
fi

echo -e "$root_password\n$root_password" | (sudo passwd root >/dev/null 2>&1)
echo -e "$user_password\n$user_password" | (sudo passwd $user_name >/dev/null 2>&1)
sudo x11vnc -storepasswd "$x11vnc_password" /etc/x11vnc.pass >/dev/null 2>&1
echo -e "$samba_password\n$samba_password" | (sudo smbpasswd -a -s $user_name)
sudo systemctl restart ssh
sudo systemctl restart x11vnc
sudo systemctl restart novnc
sudo systemctl restart smbd

if [ ! -d "$media_source" ]; then
    sudo mkdir -p $media_source
    sudo chown $user_name:$user_name $media_source
fi

if [ ! -d "$playing_source" ]; then
    sudo mkdir -p $playing_source
    sudo chown $user_name:$user_name $playing_source
fi

if [ ! -d "$local_source" ]; then
    sudo mkdir -p $local_source
    sudo chown $user_name:$user_name $local_source
fi

if [ ! -d "/tmp/mediaplayer" ]; then
    sudo mkdir -p /tmp/mediaplayer
    sudo chown $user_name:$user_name /tmp/mediaplayer
fi

if mount -L $local_source_label $local_source >/dev/null 2>&1; then
    if [ ! -d "$local_source/media" ]; then
        sudo mkdir -p "$local_source/media"
        sudo chown $user_name:$user_name "$local_source/media"
        sudo mkdir -p "$local_source/mediaplayer"
        sudo chown $user_name:$user_name "$local_source/mediaplayer"
    fi
    if [ -f "$local_source/mediaplayer/lastplayed" ]; then
        cp $(cat $local_source/mediaplayer/lastplayed) $playing_source/
        cp $local_source/mediaplayer/lastplayed /tmp/mediaplayer/lastplayed
    fi
fi

if [ -f "/tmp/mediaplayer/lastplayed" ]; then
    /usr/bin/$vlc_name $vlc_options $(cat /tmp/mediaplayer/lastplayed) >/dev/null 2>&1 &
fi

inotifywait -m $media_source -e close_write |
    while read path action file; do
        echo "The file $file appeared in directory $path via $action"
        sleep $play_pause
        xhost + >/dev/null 2>/dev/null
        mv "$path$file" "$playing_source/$file"

        kill -9 $(pidof vlc)
        echo "$playing_source/$file" >/tmp/mediaplayer/lastplayed
        find $playing_source ! -name "$file" -type f -exec rm -f {""} +
        if [ -d "$local_source/media" ] && [ -d "$local_source/mediaplayer" ]; then
            cp "$playing_source/$file" "$local_source/media/$file"
            echo "$local_source/media/$file" >$local_source/mediaplayer/lastplayed
            find $local_source/media ! -name "$file" -type f -exec rm -f {""} +
        fi
        /usr/bin/$vlc_name $vlc_options $(cat /tmp/mediaplayer/lastplayed) >/dev/null 2>&1 &
    done

EOF
chmod 755 /usr/bin/mediaplayer

systemctl disable smbd
systemctl disable x11vnc
systemctl disable novnc
systemctl disable ssh

# Cleanup
rm -f /etc/ssh/ssh_host*
rm -Rf /root/.local/share/mc
rm -Rf /root/.cache
rm -f /root/.wget-hsts
rm -f /root/.bash_history
rm -Rf /root/.ssh
rm -f /etc/fstab
rm -f /etc/ld.so.cache
rm -f /etc/ssh/ssh_host*
rm -Rf /home/live/.local/share/mc
rm -f /home/live/.bash_history
rm -Rf /home/live/.cache
rm -Rf /home/live/.ssh

if [ -d /run/initramfs/memory/changes/changes ]; then
    function savechanges {
        if [ -f /run/initramfs/lib/config ]; then
            . /run/initramfs/lib/config || exit 1
        fi

        TMP=/tmp/changes$$
        EXCLUDE="^\$|/\$|[.]wh[.][.]wh[.]orph/|^[.]wh[.][.]wh[.]plnk/|^[.]wh[.][.]wh[.]aufs|^var/cache/|^var/backups/|^var/tmp/|^var/log/|^var/lib/apt/|^var/lib/dhcp/|^var/lib/systemd/|^sbin/fsck[.]aufs|^etc/resolv[.]conf|^root/[.]Xauthority|^root/[.]xsession-errors|^root/[.]fehbg|^root/[.]fluxbox/lastwallpaper|^root/[.]fluxbox/menu_resolution|^etc/mtab|^etc/fstab|^boot/|^dev/|^mnt/|^proc/|^run/|^sys/|^tmp/"
        if [ -d /run/initramfs/memory/changes/changes ]; then
            CHANGES=/run/initramfs/memory/changes/changes
        else
            CHANGES=/run/initramfs/memory/changes
        fi

        if [ "$1" = "" ]; then
            echo ""
            echo "savechanges - save all changed files in a compressed filesystem bundle"
            echo "            - excluding some predefined files such as /etc/mtab,"
            echo "              temp & log files, empty directories, apt cache, and such"
            echo ""
            echo "Usage:"
            echo "        $0 [ target_file.sb ] [ changes_directory ]"
            echo ""
            echo "If changes_directory is not specified, /run/initramfs/memory/changes is used."
            echo ""
            exit 1
        fi

        if [ ! "$2" = "" ]; then
            CHANGES="$2"
        fi

        # exclude the save_file itself of course
        EXCLUDE="$EXCLUDE|^""$(readlink -f "$1" | cut -b 2- | sed -r "s/[.]/[.]/")""\$"

        CWD=$(pwd)

        cd $CHANGES || exit

        mkdir -p $TMP
        mount -t tmpfs tmpfs $TMP

        find \( -type d -printf "%p/\n" , -not -type d -print \) |
            sed -r "s/^[.]\\///" | egrep -v "$EXCLUDE" |
            while read FILE; do
                cp --parents -afr "$FILE" "$TMP"
            done

        cd $CWD

        mksquashfs $TMP "$1" -comp $COMP_TYPE -b 1024K -always-use-fragments -noappend

        umount $TMP
        rmdir $TMP

    }
    function genminiosiso {
        CWD=$(pwd)
        SOURCE=/run/initramfs/memory
        TEMP=/tmp/miniosiso.$$
        REGEX='^$'

        if [ "$1" = "-e" ]; then
            REGEX="$2"
            shift
            shift
        fi

        TARGET="$(readlink -f "$1")"

        if [ "$TARGET" = "" ]; then
            echo ""
            echo "Generate MiniOS ISO image, adding specified modules"
            echo "Regular expression is used to exclude any existing path or file with -e regex"
            echo ""
            echo "Usage:"
            echo "        $0 [[ -e regex ]] target.iso [[module.sb]] [[module.sb]] ..."
            echo ""
            echo "Examples:"
            echo "        # to create MiniOS iso without chromium.sb module:"
            echo "        $0 -e 'chromium' minios_without_chromium.iso"
            echo ""
            echo "        # to create MiniOS text-mode core only:"
            echo "        $0 -e 'firmware|xorg|desktop|apps|chromium' minios_textmode.iso"
            exit 1
        fi

        if [ -e "$SOURCE/data/minios/boot/isolinux.bin" ]; then
            MINIOS=$SOURCE/data/minios
        fi

        if [ -e "$SOURCE/toram/boot/isolinux.bin" ]; then
            MINIOS=$SOURCE/toram
        fi

        if [ "$MINIOS" = "" ]; then
            echo "Cannot find boot/isolinux.bin in MiniOS data" >&2
            exit 2
        fi

        GRAFT=$(
            cd "$MINIOS"
            find . -type f | sed -r "s:^[.]/::" | egrep -v "^boot/isolinux.(bin|boot)$" | egrep -v "^changes/" | egrep -v "$REGEX" | while read LINE; do
                echo "minios/$LINE=$MINIOS/$LINE"
            done
        )

        # add all modules
        while [ "$2" != "" ]; do
            if [ ! -e "$2" ]; then
                echo "File does not exist: $2"
                exit 3
            fi
            BAS="$(basename "$2")"
            MOD="$(readlink -f "$2")"
            GRAFT="$GRAFT minios/$BAS=$MOD"
            shift
        done

        (
            mkdir -p $TEMP/minios/{boot,modules,changes}
            cp "$MINIOS/boot/isolinux.bin" "$TEMP/minios/boot"
            cd "$TEMP"
            genisoimage -o - -quiet -v -J -R -D -A minios -V minios \
                -no-emul-boot -boot-info-table -boot-load-size 4 -input-charset utf-8 \
                -b minios/boot/isolinux.bin -c minios/boot/isolinux.boot \
                -graft-points $GRAFT \
                .
        ) >"$TARGET"

        rm -Rf $TEMP
    }
fi

savechanges /tmp/03-mediaplayer.sb
genminiosiso /tmp/mediaplayer.iso /tmp/03-mediaplayer.sb
