#!/bin/bash

# AI Email Assistant - Secure Deployment Script
# This script deploys the zero-knowledge, encrypted email assistant to Salesforce

echo "🚀 Starting AI Email Assistant Deployment..."
echo "✅ Features included:"
echo "   - Zero-knowledge prompting (no customer data sent to OpenAI)"
echo "   - AES-128 encryption for stored data"
echo "   - Local personalization"
echo "   - Enhanced security logging"
echo ""

# Check if Salesforce CLI is installed
if ! command -v sf &> /dev/null; then
    echo "❌ Salesforce CLI not found. Please install it first:"
    echo "   npm install -g @salesforce/cli"
    exit 1
fi

echo "📋 Pre-deployment checklist:"
echo "   1. ✅ Updated AIEmailService.cls with secure implementation"
echo "   2. ⚠️  TODO: Ensure OpenAI API key is set in Custom Labels"
echo "   3. ⚠️  TODO: Create AI_Email_Draft__c custom object if needed"
echo "   4. ⚠️  TODO: Add https://api.openai.com to Remote Site Settings"
echo ""

# Authenticate to Salesforce (if not already authenticated)
echo "🔐 Checking Salesforce authentication..."
sf org list --json > /dev/null 2>&1
if [ $? -ne 0 ]; then
    echo "🔑 Please authenticate to your Salesforce org:"
    sf org login web --alias secure-email-org
else
    echo "✅ Already authenticated to Salesforce"
fi

echo ""
echo "🚀 Deploying secure AI Email Service..."

# Deploy the updated Apex class
sf project deploy start \
    --source-dir force-app/main/default/classes/AIEmailService.cls \
    --wait 10 \
    --verbose

if [ $? -eq 0 ]; then
    echo ""
    echo "🎉 Deployment Successful!"
    echo ""
    echo "🔒 Security Features Deployed:"
    echo "   ✅ Zero-knowledge prompting implemented"
    echo "   ✅ AES-128 encryption for stored data"
    echo "   ✅ Local customer data personalization"
    echo "   ✅ Enhanced security logging"
    echo ""
    echo "⚠️  Post-deployment steps required:"
    echo "   1. Set OpenAI API key in Custom Labels (Setup → Custom Labels)"
    echo "   2. Verify AI_Email_Draft__c custom object exists"
    echo "   3. Add https://api.openai.com to Remote Site Settings"
    echo "   4. Test with a sample record to verify functionality"
    echo ""
    echo "🛡️  Your customer data is now protected - OpenAI only receives anonymous templates!"
    
else
    echo ""
    echo "❌ Deployment Failed!"
    echo "Please check the error messages above and try again."
    echo ""
    echo "Common issues:"
    echo "   - Missing AI_Email_Draft__c custom object"
    echo "   - Missing OpenAI_API_Key custom label"
    echo "   - Insufficient permissions"
    exit 1
fi