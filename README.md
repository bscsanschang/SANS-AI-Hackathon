# SANS-AI-Hackathon

## Instructions

### Step 1 (installation):

    - Install Protocol SIFT VM
    - Install all files and directories from 'Claude Directory' into your root .claude directory
    - Install all files from 'Case Directory' into your case directory
    - Add your API key to Claude or login with web auth

### Step 2 (getting evidence file):

    - Move evidence from external source to case directory

### Step 3 (set up evidence):

    - Open terminal from case directory and execute the following commands:

      sudo mkdir -p /mnt/ewf_evidence /mnt/evidence
  
      sudo ewfmount {evidenceFiles} /mnt/ewf_evidence
  
      OFFSET=$(sudo mmls /mnt/ewf_evidence/ewf1 | awk '/NTFS/{print $3; exit}')
  
      sudo mount -o ro,loop,noatime,offset=$((OFFSET*512)) /mnt/ewf_evidence/ewf1 /mnt/evidence

### Step 4 (execution):

    - Open Claude from case directory
    - Enter command such as:
      find evil in {evidenceFile} and write a PDF report

    
