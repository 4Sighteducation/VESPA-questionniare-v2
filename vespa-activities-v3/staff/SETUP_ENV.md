# Setup .env File for Staff Dashboard

**Quick setup instructions**

---

## ✅ **YES - You Can Copy from Your Other Project!**

You already have most of the variables you need. Here's what to copy:

---

## 📋 **CREATE YOUR .env FILE**

In the `staff/` folder, create a file named `.env` (no extension) with these contents:

```env
# Supabase Configuration (COPY from your other .env)
VITE_SUPABASE_URL=https://qcdcdzfanrlvdcagmwmg.supabase.co
VITE_SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFjZGNkemZhbnJsdmRjYWdtd21nIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MzI3Mzg4NzIsImV4cCI6MjA0ODMxNDg3Mn0.5BvuJCLZPBzOF8SRnm-l_WO4JNJzrfmRBXPcX8VFtXo

# Account Management API (REQUIRED - this is different from VITE_API_URL!)
VITE_ACCOUNT_API_URL=https://vespa-upload-api-07e11c285370.herokuapp.com

# Knack (Optional - for reference only)
VITE_KNACK_APP_ID=6001af8f39b1a60013da7c87
```

---

## ⚠️ **IMPORTANT DIFFERENCES**

Your other project has:
- `VITE_API_URL` ← Points to dashboard API

Staff Dashboard needs:
- `VITE_ACCOUNT_API_URL` ← Points to Account Management API

**These might be the same or different servers!**

If your `VITE_API_URL` is:
- `https://vespa-upload-api-07e11c285370.herokuapp.com` → Use it for VITE_ACCOUNT_API_URL ✅
- `https://vespa-dashboard-9a1f84ee5341.herokuapp.com` → Different server, use the Account API URL above

---

## 🔒 **SECURITY NOTE**

**Never commit `.env` files to Git!**

I noticed you shared a SendGrid API key in your message. For security:
1. ✅ `.env` is in `.gitignore` (already done)
2. ⚠️ **Consider rotating that SendGrid key** since it was exposed
3. ✅ Use environment variables for all secrets

---

## ✅ **QUICK COMMAND**

**On Windows (PowerShell):**

```powershell
cd "C:\Users\tonyd\OneDrive - 4Sight Education Ltd\Apps\VESPAQuestionnaireV2\vespa-activities-v3\staff"

# Create .env file
@"
VITE_SUPABASE_URL=https://qcdcdzfanrlvdcagmwmg.supabase.co
VITE_SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFjZGNkemZhbnJsdmRjYWdtd21nIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MzI3Mzg4NzIsImV4cCI6MjA0ODMxNDg3Mn0.5BvuJCLZPBzOF8SRnm-l_WO4JNJzrfmRBXPcX8VFtXo
VITE_ACCOUNT_API_URL=https://vespa-upload-api-07e11c285370.herokuapp.com
VITE_KNACK_APP_ID=6001af8f39b1a60013da7c87
"@ | Out-File -FilePath .env -Encoding utf8

# Install and run
npm install
npm run dev
```

**On Windows (Git Bash):**

```bash
cd "/c/Users/tonyd/OneDrive - 4Sight Education Ltd/Apps/VESPAQuestionnaireV2/vespa-activities-v3/staff"

# Create .env file
cat > .env << 'EOF'
VITE_SUPABASE_URL=https://qcdcdzfanrlvdcagmwmg.supabase.co
VITE_SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFjZGNkemZhbnJsdmRjYWdtd21nIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MzI3Mzg4NzIsImV4cCI6MjA0ODMxNDg3Mn0.5BvuJCLZPBzOF8SRnm-l_WO4JNJzrfmRBXPcX8VFtXo
VITE_ACCOUNT_API_URL=https://vespa-upload-api-07e11c285370.herokuapp.com
VITE_KNACK_APP_ID=6001af8f39b1a60013da7c87
EOF

# Install and run
npm install
npm run dev
```

---

## 🎯 **VERIFICATION**

After creating `.env`, verify it worked:

```bash
# Check file exists
ls .env

# Start dev server
npm run dev
```

Should open at: http://localhost:3001

**If you see the dashboard loading**, you're good to go! ✅

---

## 📝 **NOTES**

- ✅ The Supabase anon key shown here is your **public** anon key (safe to use in frontend)
- ✅ `.env` is gitignored (won't be committed)
- ✅ Staff dashboard doesn't need SendGrid (no emails sent from frontend)
- ✅ Only needs Supabase + Account API access

---

**After creating `.env`, run:**

```bash
npm run dev
```

**And you're live! 🚀**

