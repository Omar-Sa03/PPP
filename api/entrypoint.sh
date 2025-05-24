#!/bin/bash

# entrypoint.sh - Runtime initialization script

echo "Starting Food Advisor Backend..."

# Check if database exists, if not, seed it
if [ ! -f "./data/db.sqlite" ]; then
    echo "Database not found. Running initial seed..."
    
    # Create data directory if it doesn't exist
    mkdir -p ./data
    
    # Run the seeding process
    if yarn seed; then
        echo "✅ Database seeded successfully"
    else
        echo "❌ Database seeding failed"
        exit 1
    fi
else
    echo "✅ Database already exists, skipping seed"
fi

# Start the application
echo "🚀 Starting Strapi server..."
exec yarn start