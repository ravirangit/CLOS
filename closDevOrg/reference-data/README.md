# Optional organization fixtures

This folder is excluded from the single `force-app` package directory. It contains no package business logic. It is for development/test orgs only. Core deployment does not deploy this folder or import records.

The 15 unit records are Reference Bank → International / India → C&IB, BuB, PB, PRB under each region, plus four sample branches under India (1601, 2001, 3001, 5001). Client-specific names are unnecessary for these structural tests.

Illustrative source ranges: C&IB 1600–2000; BuB 2000–2100; PB 3000–3100; PRB 5000–5100. The supplied ranges overlap at 2000; samples avoid that boundary. These ranges do not validate product records, drive sharing, or generate branches.

After deploying the core, optionally deploy the sample taxonomy and import the tree:

```sh
sf project deploy start --source-dir reference-data/metadata --target-org closDevOrg
sf org assign permset --name LOS_Platform_Admin --target-org closDevOrg
sf data import tree --files reference-data/organization-tree.json --target-org closDevOrg
```

The permission assignment targets the currently authenticated development user and supplies CRUD/FLS for the import. It grants no Delete, View All or Modify All. It is not an automatic package-install assignment.

Import once into a clean test org. Unique external codes deliberately prevent duplicate fixture imports; this is not an upsert loader. The example is for the unnamespaced development org. A packaged subscriber import must resolve object/field API names to its installed namespace before import; never blindly concatenate namespaces.

The nested tree connects parents without embedded Salesforce IDs; organization-units.json is the flat, reviewable fixture inventory. The four sample taxonomy records are unprotected subscriber-controlled Custom Metadata records, outside the package core. No user assignments, bank data, application data, or security grants are imported.
