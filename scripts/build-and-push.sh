set -euo pipefail

REGISTRY="zot.synetic.fyi"
IMAGE="betaflight-sitl"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

VERSION_FILE="scripts/VERSION"
DOCKERFILE=".devcontainer/containerfile.sitl"
PLATFORM="${PLATFORM:-linux/amd64}"

if [[ ! -f "$VERSION_FILE" ]]; then
  echo "error: $VERSION_FILE missing (it is the persistent version counter)" >&2
  exit 1
fi

CURRENT="$(tr -d ' \t\n\r' < "$VERSION_FILE")"
if [[ -z "${CURRENT:-}" ]]; then
  echo "error: could not read a version from $VERSION_FILE" >&2
  exit 1
fi

# Next version: an explicit arg wins; otherwise bump the patch component.
if [[ $# -ge 1 ]]; then
  VERSION="$1"
  if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "error: explicit version '$VERSION' is not MAJOR.MINOR.PATCH" >&2
    exit 1
  fi
else
  if [[ ! "$CURRENT" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "error: cannot auto-bump non-semver version '$CURRENT'; pass one explicitly" >&2
    exit 1
  fi
  IFS=. read -r major minor patch <<<"$CURRENT"
  VERSION="${major}.${minor}.$((patch + 1))"
fi

if [[ "$VERSION" == "$CURRENT" ]]; then
  echo "error: new version equals current version ($VERSION); nothing to advance" >&2
  exit 1
fi

echo "Ensuring SITL submodules are checked out…"
git submodule update --init lib/main/dyad src/config

REPO="${REGISTRY}/${IMAGE}"

echo "Version: ${CURRENT} -> ${VERSION}"
echo "Building ${REPO}:${VERSION} (${PLATFORM}) from ${DOCKERFILE}"
docker build \
  --platform "$PLATFORM" \
  -f "$DOCKERFILE" \
  -t "${REPO}:${VERSION}" \
  -t "${REPO}:latest" \
  .

for tag in "${VERSION}" latest; do
  echo "Pushing ${REPO}:${tag}"
  docker push "${REPO}:${tag}"
done

printf '%s\n' "$VERSION" > "$VERSION_FILE"

echo "Done: ${REPO}:${VERSION} (${VERSION_FILE} bumped, uncommitted)"
