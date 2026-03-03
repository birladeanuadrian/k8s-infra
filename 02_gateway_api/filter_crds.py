import sys

def filter_crds(input_file):
    with open(input_file, 'r', encoding='utf-8') as f:
        content = f.read()

    # Split by YAML document separator
    docs = content.split('\n---')

    for doc in docs:
        doc_str = doc.strip()
        if not doc_str:
            continue

        # Check if it's a CustomResourceDefinition
        if 'kind: CustomResourceDefinition' not in doc_str:
            continue

        # Check if it belongs to gateway.envoyproxy.io group
        # CRD names are typically <plural>.<group>
        # e.g. envoyproxies.gateway.envoyproxy.io
        # We look for "gateway.envoyproxy.io" in the name field or just in the document generally for CRD definition
        # Safer to look for "name: " followed by something containing gateway.envoyproxy.io
        # Or just check if "gateway.envoyproxy.io" is in the document, which for a CRD of that group, it must be (in metadata.name).
        if 'gateway.envoyproxy.io' in doc_str:
             print('---')
             print(doc_str)

if __name__ == "__main__":
    if len(sys.argv) < 2:
        sys.stderr.write("Usage: python filter_crds.py <file>\n")
        sys.exit(1)

    filter_crds(sys.argv[1])

