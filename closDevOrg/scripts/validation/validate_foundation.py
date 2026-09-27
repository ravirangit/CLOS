#!/usr/bin/env python3
"""Offline structural and product-contract checks; no org credentials required."""
from pathlib import Path
import json
import unittest
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'force-app/main/default'
NS = {'m': 'http://soap.sforce.com/2006/04/metadata'}
def get(root, path):
    return root.findtext('/'.join('m:' + x for x in path.split('/')), namespaces=NS)
def records(kind):
    result = {}
    for path in (SOURCE / 'customMetadata').glob('LOS_' + kind + '.*.md-meta.xml'):
        root = ET.parse(path).getroot()
        values = {get(v, 'field'): get(v, 'value') for v in root.findall('m:values', NS)}
        result[path.name.split('.')[1]] = values
    return result

class FoundationContract(unittest.TestCase):
    def test_xml_and_namespace_safety(self):
        for path in SOURCE.rglob('*.xml'):
            root = ET.parse(path).getroot()
            self.assertTrue(root.tag.startswith('{' + NS['m'] + '}'))
            self.assertNotIn('LOS__', path.read_text())
            self.assertNotIn('Axis Bank', path.read_text())
        project = json.loads((ROOT / 'sfdx-project.json').read_text())
        self.assertEqual([p['path'] for p in project['packageDirectories']], ['force-app'])
        self.assertEqual(project['namespace'], '')
        for suffix in ['*.flow-meta.xml', '*.js']:
            self.assertEqual(list(SOURCE.rglob(suffix)), [])

    def test_lifecycle_graph(self):
        stages = records('Stage')
        self.assertEqual(set(stages), {'Draft', 'Underwriting', 'RM_TL_Review', 'Credit_Review', 'Approved', 'Documentation', 'Ready_for_Booking', 'Booked', 'Monitoring'})
        self.assertEqual(len({v['LOS_Code__c'] for v in stages.values()}), 9)
        self.assertEqual({v['LOS_Code__c'] for v in stages.values() if v['LOS_Terminal_Stage__c'] == 'true'}, {'Monitoring'})
        transitions = records('Stage_Transition')
        edges = {(v['LOS_From_Stage__c'], v['LOS_To_Stage__c'], v['LOS_Transition_Type__c']) for v in transitions.values()}
        ordered = ['Draft', 'Underwriting', 'RM_TL_Review', 'Credit_Review', 'Approved', 'Documentation', 'Ready_for_Booking', 'Booked', 'Monitoring']
        expected = {(a,b,'Approval' if b == 'Approved' else 'Forward') for a,b in zip(ordered, ordered[1:])}
        expected |= {(a,b,'Rework') for a,bs in [('RM_TL_Review',['Draft','Underwriting']),('Credit_Review',['Draft','Underwriting','RM_TL_Review'])] for b in bs}
        self.assertEqual(edges, expected)
        self.assertEqual(len(transitions), 13)
        for v in transitions.values():
            self.assertEqual(v['LOS_Active__c'], 'true')
            self.assertEqual(v['LOS_Requires_Validation__c'], 'true')
            if v['LOS_Transition_Type__c'] == 'Rework': self.assertEqual(v['LOS_Requires_Reason__c'], 'true')
        self.assertEqual(set(records('Application_Type')), {'New', 'Renewal', 'Modification'})

    def test_stage_status_and_registry_contract(self):
        expected = {'Draft':'In Progress','Underwriting':'In Progress','RM_TL_Review':'In Review','Credit_Review':'In Review','Approved':'Approved','Documentation':'Approved','Ready_for_Booking':'Approved','Booked':'Booked','Monitoring':'Active'}
        self.assertEqual({k:v['LOS_Default_Application_Status__c'] for k,v in records('Stage').items()}, expected)
        for path in (SOURCE/'classes').glob('*.cls'):
            if '@IsTest' not in path.read_text():
                self.assertNotIn('Type.forName', path.read_text())
        registry = (SOURCE/'classes/LOS_ValidationRegistry.cls').read_text()
        self.assertIn('private static void registerTestHook', registry)
        self.assertIn('!Test.isRunningTest()', registry)

    def test_configuration_and_references(self):
        objects = {p.parent.name for p in (SOURCE / 'objects').glob('*/*.object-meta.xml')}
        self.assertEqual(len(objects), 18)
        for path in (SOURCE / 'objects').rglob('*.field-meta.xml'):
            root = ET.parse(path).getroot()
            ref = get(root, 'referenceTo')
            if ref: self.assertIn(ref, objects | {'Account','User'})
            relationship = get(root, 'relationshipName')
            if relationship: self.assertLessEqual(len(relationship), 40)
            if path.parent.parent.name.endswith('__mdt'):
                self.assertEqual(get(root, 'fieldManageability'), 'SubscriberControlled')
        for path in (SOURCE / 'customMetadata').glob('*.xml'):
            root = ET.parse(path).getroot()
            self.assertEqual(get(root, 'protected'), 'false')
            for value in root.findall('m:values', NS):
                val = get(value, 'value')
                if get(value, 'field') in ['LOS_From_Stage__c','LOS_To_Stage__c']:
                    self.assertTrue((SOURCE / 'customMetadata' / ('LOS_Stage.'+val+'.md-meta.xml')).exists())

    def test_security_and_immutable_audit(self):
        for path in (SOURCE / 'objects').glob('*__c/*.object-meta.xml'):
            root = ET.parse(path).getroot()
            self.assertEqual(get(root, 'sharingModel'), 'Private')
            self.assertEqual(get(root, 'externalSharingModel'), 'Private')
        for path in (SOURCE / 'permissionsets').glob('*.xml'):
            root = ET.parse(path).getroot()
            for perm in root.findall('m:objectPermissions', NS):
                for name in ['allowDelete','modifyAllRecords','viewAllRecords']:
                    self.assertEqual(get(perm,name), 'false')
                if get(perm,'object') == 'LOS_Lifecycle_History__c':
                    self.assertEqual(get(perm,'allowEdit'), 'false')
                    if path.name.startswith('LOS_Lending_User'): self.assertEqual(get(perm,'allowCreate'), 'false')
                if path.name.startswith('LOS_Lending_User') and get(perm,'object') not in ['LOS_Relationship__c','LOS_Credit_Application__c']:
                    self.assertEqual(get(perm,'allowEdit'), 'false')
                    self.assertEqual(get(perm,'allowCreate'), 'false')
        audit = ET.parse(SOURCE / 'objects/LOS_Lifecycle_History__c/validationRules/LOS_Immutable_History.validationRule-meta.xml').getroot()
        self.assertEqual(get(audit,'errorConditionFormula'), 'NOT(ISNEW())')
        for name in ['Business_Unit','Segment','Branch']:
            root = ET.parse(SOURCE / f'objects/LOS_Credit_Application__c/fields/LOS_{name}_Snapshot__c.field-meta.xml').getroot()
            self.assertEqual(get(root,'type'), 'Text')
            self.assertIsNone(get(root,'formula'))

    def test_required_users_and_metadata_layouts(self):
        for obj, field in [('LOS_Application_Team__c','LOS_User__c'), ('LOS_User_Org_Assignment__c','LOS_User__c'), ('LOS_Lifecycle_History__c','LOS_Performed_By__c'), ('LOS_Stage_TAT__c','LOS_Started_By__c')]:
            name = 'LOS_Required_' + field.removeprefix('LOS_').removesuffix('__c')
            root = ET.parse(SOURCE / 'objects' / obj / 'validationRules' / (name + '.validationRule-meta.xml')).getroot()
            self.assertEqual(get(root,'errorConditionFormula'), 'ISBLANK(' + field + ')')
            self.assertEqual(get(root,'active'), 'true')
        for path in (SOURCE / 'layouts').glob('*__mdt-*'):
            root = ET.parse(path).getroot()
            present = {n.text for n in root.findall('.//m:field',NS)}
            self.assertTrue({'DeveloperName','MasterLabel','IsProtected','NamespacePrefix'} <= present)

    def test_reference_hierarchy(self):
        rows = json.loads((ROOT / 'reference-data/organization-units.json').read_text())['records']
        tree = json.loads((ROOT / 'reference-data/organization-tree.json').read_text())['records']
        flattened = []
        def flatten(nodes, parent=None):
            for node in nodes:
                row = {k:v for k,v in node.items() if k != 'LOS_Organization_Unit_Parent_Unit__r'}
                if parent: row['LOS_Parent_Unit__c'] = '@' + parent
                flattened.append(row)
                flatten(node.get('LOS_Organization_Unit_Parent_Unit__r', {}).get('records', []), node['attributes']['referenceId'])
        flatten(tree)
        key = lambda r: r['attributes']['referenceId']
        self.assertEqual(sorted(rows,key=key),sorted(flattened,key=key))
        self.assertEqual(len(rows),15)
        refs = {r['attributes']['referenceId'] for r in rows}
        self.assertEqual(len(refs),len(rows))
        branches = [r for r in rows if r['LOS_Unit_Type__c'] == 'Branch']
        self.assertEqual(len(branches),4)
        for row in rows:
            if 'LOS_Parent_Unit__c' in row: self.assertIn(row['LOS_Parent_Unit__c'][1:],refs)
        for row in branches:
            self.assertTrue(row['LOS_Parent_Unit__c'].startswith('@REF_India_'))

if __name__ == '__main__': unittest.main(verbosity=2)
