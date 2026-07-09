// Mounts an SMB share at a given mount point if it isn't already mounted.
// Deliberately a compiled Mach-O binary rather than a shell script: rcodesign
// (used to sign it for a nicer System Settings > Login Items identity — see
// scripts/sign-launchd-agents.ts and knowledge/decisions/nas-mount-codesigning.md)
// only recognizes Mach-O/bundle/DMG/pkg, not plain scripts.
//
// usage: nas-mount <mount-point> <smb-share>

use std::env;
use std::fs;
use std::process::{Command, ExitCode};

fn main() -> ExitCode {
    let args: Vec<String> = env::args().collect();
    let [mount_point, share] = match &args[1..] {
        [mount_point, share] => [mount_point, share],
        _ => {
            eprintln!("usage: nas-mount <mount-point> <smb-share>");
            return ExitCode::FAILURE;
        }
    };

    if let Err(e) = fs::create_dir_all(mount_point) {
        eprintln!("mkdir -p {mount_point} failed: {e}");
        return ExitCode::FAILURE;
    }

    let already_mounted = match Command::new("/sbin/mount").output() {
        Ok(o) => String::from_utf8_lossy(&o.stdout).contains(&format!(" on {mount_point} ")),
        Err(e) => {
            eprintln!("mount failed: {e}");
            return ExitCode::FAILURE;
        }
    };
    if already_mounted {
        return ExitCode::SUCCESS;
    }

    match Command::new("/sbin/mount_smbfs").arg("-N").arg(share).arg(mount_point).status() {
        Ok(s) if s.success() => ExitCode::SUCCESS,
        Ok(s) => {
            eprintln!("mount_smbfs exited with {s}");
            ExitCode::FAILURE
        }
        Err(e) => {
            eprintln!("mount_smbfs failed: {e}");
            ExitCode::FAILURE
        }
    }
}
