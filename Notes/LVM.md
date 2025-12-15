# LVM Complete Practical Guide (Linux Logical Volume Manager)

This is a **complete, real-world, end-to-end LVM guide** written using an **actual Rocky Linux default installation**. Nothing here is theoretical. Every concept is mapped to real devices, real commands, and real admin scenarios you will face in production.

We start from what you already have.

---

<br>
<br>

## 0. Baseline system (REAL, not imaginary)

```bash
pgohel@rocky01:~$ lsblk -f
NAME        FSTYPE      FSVER    LABEL UUID                                   FSAVAIL FSUSE% MOUNTPOINTS
sr0                                                                                          
nvme0n1                                                                                      
├─nvme0n1p1                                                                                  
├─nvme0n1p2 xfs                        ba2382f0-03f2-4610-add0-bfc7c5ad8cca    495.6M    48% /boot
└─nvme0n1p3 LVM2_member LVM2 001       DZF3nl-MRKn-tD0F-wQ3Y-6mH6-CaQF-hih0Gl                
  ├─rl-root xfs                        023c3787-9286-40dc-afb2-64149e6905d0     12.3G    27% /
  └─rl-swap swap        1              7ae13f5a-8933-438d-ab3f-8c9d6ac9952d                  [SWAP]
```

### What this means (clear mapping)

- Disk → `/dev/nvme0n1`
- Partition used by LVM → `/dev/nvme0n1p3`
- Physical Volume (PV) → `/dev/nvme0n1p3`
- Volume Group (VG) → `rl`
- Logical Volumes (LVs)
  - `rl-root` → `/`
  - `rl-swap` → swap

If you can’t mentally map this, you will never be comfortable with LVM.

---

<br>
<br>

## 1. Why LVM exists (practical reason)

Without LVM, `/` would be a fixed partition. If it fills up, your only options are downtime or reinstall.

With LVM:
- disks can be added live
- `/` can grow online
- data can be moved off failing disks
- snapshots can be taken safely

That is why every enterprise Linux install uses LVM.

---

<br>
<br>

## 2. Inspecting LVM safely (first rule)

Never modify LVM blindly. Always inspect.

```bash
lsblk
lsblk -f
pvs
vgs
lvs
```

Detailed inspection:
```bash
pvdisplay
vgdisplay
lvdisplay
```

These commands are **read-only and safe**.

---

<br>
<br>

## 3. Adding a NEW disk to an existing LVM system

### Scenario: disk `/dev/nvme1n1` added

Check:
```bash
lsblk
```

Create Physical Volume:
```bash
pvcreate /dev/nvme1n1
```

Extend existing VG `rl`:
```bash
vgextend rl /dev/nvme1n1
```

Verify:
```bash
vgs
```

Now `rl` has more free space.

---

<br>
<br>

## 4. EXPANDING logical volumes (most common task)

### 4.1 Expand root filesystem (XFS)

Your `/` is:
```
/dev/rl/root (xfs)
```

Extend LV:
```bash
lvextend -l +100%FREE /dev/rl/root
```

Grow filesystem **online**:
```bash
xfs_growfs /
```

Verify:
```bash
df -h /
```

No reboot. No unmount.

---

### 4.2 Expand swap LV

```bash
swapon --show
```

Extend swap by 2G:
```bash
swapoff /dev/rl/swap
lvextend -L +2G /dev/rl/swap
mkswap /dev/rl/swap
swapon /dev/rl/swap
```

---

### 4.3 Expand any mounted ext4 filesystem

(ext4 supports online grow)

```bash
lvextend -L +5G /dev/rl/data
resize2fs /dev/rl/data
```

---

<br>
<br>

## 5. SHRINKING logical volumes (danger zone)

⚠️ **Rule 1: XFS CANNOT BE SHRUNK**

If filesystem is XFS:
- shrinking is impossible
- backup → recreate → restore is the only way

---

### 5.1 Shrinking ext4 safely

Correct order (no shortcuts):

```bash
umount /data
e2fsck -f /dev/rl/data
resize2fs /dev/rl/data 10G
lvreduce -L 10G /dev/rl/data
mount /data
```

Wrong order = data loss.

---

<br>
<br>

## 6. Creating NEW logical volumes

### Scenario: create `/data`

```bash
lvcreate -L 20G -n data rl
mkfs.xfs /dev/rl/data
mkdir /data
mount /dev/rl/data /data
```

Persist:
```bash
echo "/dev/rl/data /data xfs defaults 0 0" >> /etc/fstab
```

---

<br>
<br>

## 7. LVM Snapshots (backup & testing)

Snapshots are **temporary**.

Create snapshot of root:
```bash
lvcreate -L 2G -s -n root_snap /dev/rl/root
```

Mount snapshot:
```bash
mkdir /mnt/root_snap
mount /dev/rl/root_snap /mnt/root_snap
```

Delete snapshot:
```bash
umount /mnt/root_snap
lvremove /dev/rl/root_snap
```

⚠️ Leaving snapshots for long time degrades performance.

---

<br>
<br>

## 8. Disk FAILURE handling (enterprise critical skill)

### Scenario: `/dev/nvme0n1p3` failing

If another PV exists:

```bash
pvmove /dev/nvme0n1p3
```

Remove disk from VG:
```bash
vgreduce rl /dev/nvme0n1p3
pvremove /dev/nvme0n1p3
```

System stays online.

---

<br>
<br>

## 9. Replacing a disk (zero downtime)

```bash
pvcreate /dev/nvme2n1
vgextend rl /dev/nvme2n1
pvmove /dev/nvme0n1p3 /dev/nvme2n1
vgreduce rl /dev/nvme0n1p3
```

---

<br>
<br>

## 10. Thin provisioning (advanced, dangerous if ignored)

Create thin pool:
```bash
lvcreate -L 50G -T rl/thinpool
```

Create thin LV:
```bash
lvcreate -V 200G -T rl/thinpool -n thin_data
```

Monitor:
```bash
lvs
```

⚠️ If thin pool fills → ALL thin LVs freeze.

---

<br>
<br>

## 11. LVM metadata backup & recovery

Backup:
```bash
vgcfgbackup rl
```

Restore:
```bash
vgcfgrestore rl
```

Metadata locations:
```
/etc/lvm/backup/
/etc/lvm/archive/
```

---

<br>
<br>

## 12. Activating and deactivating LVs

```bash
lvchange -ay rl/root
lvchange -an rl/root
```

Useful during recovery.

---

<br>
<br>

## 13. Renaming VG and LV (real admin task)

```bash
vgrename rl vg_main
lvrename vg_main root root_os
```

Update `/etc/fstab` after renaming.

---

<br>
<br>

## 14. Performance considerations

- Avoid long-lived snapshots
- Monitor thin pools
- Keep VG names simple
- Use SSDs for metadata-heavy workloads
- Align partitions

---

<br>
<br>

## 15. Common LVM mistakes (learn these)

- Forgetting filesystem resize after lvextend
- Trying to shrink XFS
- Deleting wrong LV
- Filling thin pool
- Not backing up metadata
- Panic editing disks without lsblk check

---

<br>
<br>

## 16. Real admin checklist (before any change)

- `lsblk -f`
- `pvs / vgs / lvs`
- Confirm filesystem type
- Take snapshot or backup
- Have rollback plan

---

<br>
<br>

## 17. Command cheat sheet

```bash
pvcreate /dev/nvme1n1
vgextend rl /dev/nvme1n1
lvextend -l +100%FREE /dev/rl/root
xfs_growfs /
resize2fs /dev/rl/data
pvmove /dev/nvme0n1p3
vgcfgbackup rl
```

---

<br>
<br>

## What you gain from this file

You now understand **ALL LVM scenarios**:
- expansion
- shrinking (safe vs unsafe)
- snapshots
- disk replacement
- failure recovery
- thin provisioning
- metadata recovery

This is **production-grade LVM knowledge**, exactly what a Linux administrator is expected to know.
