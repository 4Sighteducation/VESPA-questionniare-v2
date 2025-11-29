#!/bin/bash

# VESPA Staff Dashboard V3 - Deployment Script
# Run this to build and prepare for deployment

echo "🚀 VESPA Staff Dashboard V3 - Deployment Script"
echo "================================================"
echo ""

# Check if .env exists
if [ ! -f .env ]; then
    echo "❌ Error: .env file not found!"
    echo "Please create .env file with your Supabase credentials"
    echo "See .env.example for template"
    exit 1
fi

echo "✅ Environment file found"
echo ""

# Install dependencies
echo "📦 Installing dependencies..."
npm install

if [ $? -ne 0 ]; then
    echo "❌ Failed to install dependencies"
    exit 1
fi

echo "✅ Dependencies installed"
echo ""

# Run build
echo "🔨 Building for production..."
npm run build

if [ $? -ne 0 ]; then
    echo "❌ Build failed"
    exit 1
fi

echo "✅ Build successful"
echo ""

# Check output
if [ -d "dist" ]; then
    echo "📁 Build output:"
    ls -lh dist/
    echo ""
    echo "📊 Bundle sizes:"
    du -sh dist/*
    echo ""
else
    echo "❌ dist/ folder not found"
    exit 1
fi

echo "✅ Deployment build complete!"
echo ""
echo "Next steps:"
echo "1. Upload dist/ folder to your CDN or hosting service"
echo "2. Update Knack page to point to new bundle"
echo "3. Test with real staff account"
echo "4. Monitor Supabase logs for errors"
echo ""
echo "🎉 Ready to deploy!"

