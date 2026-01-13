#!/bin/bash
# Release script - updates VERSION file and creates git tag
# Usage: ./scripts/release.sh 1.2.0

set -e

if [ -z "$1" ]; then
    echo "Usage: $0 <version>"
    echo "Example: $0 1.2.0"
    exit 1
fi

VERSION=$1
TAG="v$VERSION"

# Validate version format
if ! [[ $VERSION =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "Error: Version must be in format X.Y.Z (e.g., 1.2.0)"
    exit 1
fi

# Check for uncommitted changes
if ! git diff-index --quiet HEAD --; then
    echo "Error: You have uncommitted changes. Commit or stash them first."
    exit 1
fi

# Check if tag already exists
if git rev-parse "$TAG" >/dev/null 2>&1; then
    echo "Error: Tag $TAG already exists"
    exit 1
fi

echo "Releasing version $VERSION..."

# Update VERSION file
echo "$VERSION" > VERSION

# Commit the version bump
git add VERSION
git commit -m "Bump version to $VERSION"

# Create and push tag
git tag "$TAG"

echo ""
echo "✓ Version updated to $VERSION"
echo "✓ Created tag $TAG"
echo ""
echo "To publish the release, run:"
echo "  git push origin main --tags"
echo ""
echo "GitHub Actions will automatically create the release."
