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

### Step 4 (set up case CLAUDE.md)

    - Modify CLAUDE.md in case directory to reflect anything specific to this case such as the name of the evidence file, name of the case, etc.

### Step 5 (execution):

    - Open Claude from case directory
    - Enter command such as:
      find evil in {evidenceFile} and write a PDF report

## Architecture

### SIFT Workstation
<img width="944" height="958" alt="SIFT_Workstation" src="https://github.com/user-attachments/assets/e93d1e77-aae1-49c9-bd7e-bf20c0f73a4f" />

### Report Pipeline
<img width="967" height="374" alt="Output pipeline" src="https://github.com/user-attachments/assets/080033c5-771f-4a5c-8f0b-d08a63b5bea9" />

### Evidence Integrity
The agent is given read-only access to the mounted evidence source. Generated files are directed to separate output locations for analysis artifacts, exports, logs, and reports. The workflow is designed so that the original evidence image and mounted evidence filesystem are not used as working directories for generated output.

In addition, every forensic command executed by the agent is required to go through a logging hook/wrapper. This command-logging mechanism records the command that was run, the working directory, timestamps, stdout/stderr locations, exit status, and related notes. This creates an audit trail showing what the agent did during the run and allows you to review whether the agent’s report claims are supported by actual commands.



    
