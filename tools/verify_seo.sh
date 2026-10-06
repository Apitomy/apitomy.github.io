#!/usr/bin/env bash
# SEO invariants over a rendered _site directory from the real Pages toolchain.
# Usage: tools/verify_seo.sh [SITE_DIR]   (default ./_site)
set -u
SITE="${1:-./_site}"
FAIL=0
note() { printf '%s\n' "$*"; }
fail() { printf 'FAIL %s\n' "$*"; FAIL=$((FAIL + 1)); }
need() { grep -q "$2" "$1" || fail "$1: $3"; }
exact1() { local n; n=$(grep -c "$2" "$1"); [ "$n" -eq 1 ] || fail "$1: $n $3"; }

[ -d "$SITE" ] || { fail "site dir $SITE missing"; exit 1; }
SRC_PROJECTS=$(ls _pages/projects/*.html 2>/dev/null | wc -l | tr -d ' ')
SRC_POSTS=$(ls _posts/*.md 2>/dev/null | wc -l | tr -d ' ')

# Pages rendered by the Jekyll layouts are exactly the files carrying the
# seo-tag marker; everything else (mkdocs docs, demos) is out of scope.
PAGES=()
while IFS= read -r f; do PAGES+=("$f"); done < <(grep -rl --include='*.html' 'Begin Jekyll SEO tag' "$SITE" | sort)
[ "${#PAGES[@]}" -ge 10 ] || fail "expected >=10 rendered pages, found ${#PAGES[@]}"
note "checking ${#PAGES[@]} rendered pages"

descs_seen=""
for f in "${PAGES[@]}"; do
    exact1 "$f" '<title>' "<title> tags"
    exact1 "$f" 'name="description"' "meta descriptions"
    need "$f" 'rel="canonical" href="https://www.apitomy.io' "no absolute canonical"
    need "$f" 'property="og:image" content="https://www.apitomy.io/assets/images/og-default.png"' "no og:image absolute URL"
    need "$f" 'name="twitter:card" content="summary_large_image"' "twitter card not summary_large_image"
    d=$(grep -o 'name="description" content="[^"]*"' "$f" | head -1)
    descs_seen+="$d"$'\n'
done
note "${#PAGES[@]} pages carry exactly one title, description, canonical, og:image, large card"

dup=$(printf '%s' "$descs_seen" | sort | uniq -d)
[ -z "$dup" ] || fail "duplicate meta descriptions across pages:"$'\n'"$dup"

home="$SITE/index.html"
grep -q '<title>Apitomy | Open-Source OpenAPI and AsyncAPI Tools</title>' "$home" \
    || fail "homepage title is not the brand+tagline form"
grep -q 'View on GitHub Read the Blog' "$home" \
    && fail "homepage description still leaks UI text"

project_found=0
for f in "$SITE"/projects/*/index.html; do
    [ -f "$f" ] || continue
    case "$f" in */docs/*) continue ;; esac
    project_found=$((project_found + 1))
done
[ "$project_found" -eq "$SRC_PROJECTS" ] \
    || fail "expected $SRC_PROJECTS project pages from _pages/projects, found $project_found"

post_found=$(find "$SITE/blog" -name index.html -path '*20*' | wc -l | tr -d ' ')
[ "$post_found" -eq "$SRC_POSTS" ] || fail "expected $SRC_POSTS rendered posts, found $post_found"
post_links=$(grep -l 'Explore the Apitomy tools' "$SITE"/blog/20*/*/*/*/index.html 2>/dev/null | wc -l | tr -d ' ')
[ "$post_links" -eq "$SRC_POSTS" ] || fail "only $post_links/$SRC_POSTS posts carry the tools cross-links"

for asset in og-default.png logo.png favicon.ico favicon-16.png favicon-32.png apple-touch-icon.png; do
    [ -s "$SITE/assets/images/$asset" ] || fail "missing asset assets/images/$asset"
done
note "brand assets present in _site"

for d in scripts tools; do
    [ ! -e "$SITE/$d" ] || fail "dev directory $d leaked into _site"
done

[ -s "$SITE/robots.txt" ] || fail "missing robots.txt"
grep -q 'Sitemap: https://www.apitomy.io/sitemap.xml' "$SITE/robots.txt" || fail "robots.txt lacks sitemap line"
[ -s "$SITE/404.html" ] || fail "missing 404.html"

n_url=$(grep -c '<loc>' "$SITE/sitemap.xml")
[ "$n_url" -ge 140 ] || fail "sitemap lost URLs: $n_url < 140"
note "sitemap has $n_url URLs"

# Semantic JSON-LD checks on the parsed graph, over the same page list,
# replacing every format-sensitive grep on serializer whitespace.
printf '%s\n' "${PAGES[@]}" | python3 - "$SITE" <<'PY'
import json, pathlib, re, sys

site = pathlib.Path(sys.argv[1])
pages = [site.parent / pathlib.Path(line.strip()).relative_to(site)
         for line in sys.stdin if line.strip()]

def kind(rel):
    p = rel.as_posix()
    if p == "index.html":
        return "home"
    if p == "blog/index.html":
        return "blog"
    if p.startswith("blog/") and re.search(r"/20\d\d/", p):
        return "post"
    if p.startswith("projects/") and "/docs/" not in p and p.endswith("/index.html"):
        return "project"
    return "other"

bad = 0
def check(cond, msg):
    global bad
    if not cond:
        bad += 1
        print(f"FAIL {msg}")

for rel in pages:
    text = (site / rel).read_text(errors="replace")
    blocks = []
    for m in re.finditer(r'<script type="application/ld\+json">\s*(.*?)\s*</script>', text, re.S):
        try:
            blocks.append(json.loads(m.group(1)))
        except json.JSONDecodeError as e:
            check(False, f"{rel}: invalid JSON-LD ({e})")
    types = {b.get("@type") for b in blocks}

    k = kind(rel)
    if k != "post":
        check("BlogPosting" not in types,
              f"{rel}: BlogPosting JSON-LD on a {k or 'non-post'} page")

    # og:type is article iff the page carries a date (seo-tag 2.8 template);
    # landing pages get the frozen launch date from the _pages defaults scope.
    # Accepted contract: OG says article, JSON-LD says WebSite/WebPage; the
    # freeze below is what must never regress back to build-time churn.
    og_type = re.search(r'property="og:type" content="(\w+)"', text)
    check(bool(og_type), f"{rel}: no og:type")
    if og_type:
        if k == "other":
            check(og_type.group(1) == "website", f"{rel}: og:type {og_type.group(1)} on undated page")
        else:
            check(og_type.group(1) == "article", f"{rel}: og:type {og_type.group(1)} on dated page")
    if k != "post":
        m = re.search(r'property="article:published_time" content="([^"]+)"', text)
        check(bool(m) and m.group(1).startswith("2026-05-20"),
              f"{rel}: article:published_time not frozen at 2026-05-20")
    if k == "home":
        orgs = [b for b in blocks if b.get("@type") == "Organization"]
        check(len(orgs) == 1, f"{rel}: expected 1 Organization node, found {len(orgs)}")
        if orgs:
            o = orgs[0]
            check(o.get("url") == "https://www.apitomy.io", f"{rel}: Organization url {o.get('url')}")
            check("https://github.com/Apitomy" in (o.get("sameAs") or []),
                  f"{rel}: Organization sameAs missing GitHub")
            check(str(o.get("logo", {}).get("url", "")).endswith("logo.png"),
                  f"{rel}: Organization logo missing")
        site_nodes = [b for b in blocks if b.get("@type") == "WebSite"]
        check(bool(site_nodes) and str(site_nodes[0].get("datePublished", "")).startswith("2026-05-20"),
              f"{rel}: WebSite datePublished not frozen at 2026-05-20")
    if k == "project":
        apps = [b for b in blocks if b.get("@type") == "SoftwareApplication"]
        check(len(apps) == 1, f"{rel}: expected 1 SoftwareApplication node")
        if apps:
            a = apps[0]
            check(bool(a.get("name")) and bool(a.get("url")) and bool(a.get("sameAs")),
                  f"{rel}: SoftwareApplication missing name/url/sameAs")
            check(a.get("applicationCategory") == "DeveloperApplication",
                  f"{rel}: SoftwareApplication category wrong")
    if k == "blog":
        check("WebPage" in types, f"{rel}: blog index not typed WebPage")

sys.exit(1 if bad else 0)
PY
[ $? -eq 0 ] || fail "JSON-LD semantic checks failed (details above)"
note "JSON-LD graph checks passed"

if [ "$FAIL" -eq 0 ]; then
    note "SEO VERIFY: ALL CHECKS PASSED"
else
    note "SEO VERIFY: $FAIL FAILURES"
fi
exit "$FAIL"
