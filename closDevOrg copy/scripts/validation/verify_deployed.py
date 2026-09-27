#!/usr/bin/env python3
"""Read-only org verification of Task 01. Requires authenticated Salesforce CLI."""
import argparse
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timezone
import json
from pathlib import Path
import subprocess
import sys
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'force-app/main/default'
NS = {'m':'http://soap.sforce.com/2006/04/metadata'}

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--target-org', required=True)
    parser.add_argument('--output', required=True)
    parser.add_argument('--expect-reference-data', action='store_true')
    args = parser.parse_args()
    def sf(*parts):
        proc = subprocess.run(['sf', *parts, '--target-org', args.target_org, '--json'], capture_output=True, text=True, timeout=120)
        try:
            body = json.loads(proc.stdout)
        except json.JSONDecodeError:
            raise RuntimeError('Salesforce CLI returned non-JSON output for ' + parts[0])
        if proc.returncode or body.get('status'):
            raise RuntimeError(body.get('message','Salesforce CLI command failed'))
        return body['result']
    def query(q, tooling=False):
        flags = ['--use-tooling-api'] if tooling else []
        return sf('data','query','--query',q,*flags)['records']
    def describe(obj):
        result = sf('sobject','describe','--sobject',obj)
        expected = {p.name.removesuffix('.field-meta.xml') for p in (SOURCE/'objects'/obj/'fields').glob('*.xml')}
        actual = {f['name'] for f in result['fields']}
        assert expected <= actual, f'{obj}: missing {expected-actual}'
        return {'object':obj,'verifiedCustomFields':len(expected)}
    objects = sorted(p.parent.name for p in (SOURCE/'objects').glob('*/*.object-meta.xml'))
    with ThreadPoolExecutor(max_workers=3) as pool:
        descriptions = list(pool.map(describe,objects))
    stages = query('SELECT DeveloperName, LOS_Code__c, LOS_Sequence__c, LOS_Terminal_Stage__c, LOS_Active__c FROM LOS_Stage__mdt ORDER BY LOS_Sequence__c')
    assert len(stages)==9
    expected_stages = ['Draft','Underwriting','RM_TL_Review','Credit_Review','Approved','Documentation','Ready_for_Booking','Booked','Monitoring']
    assert [s['LOS_Code__c'] for s in stages]==expected_stages
    assert all(s['LOS_Active__c'] for s in stages)
    assert [s['LOS_Code__c'] for s in stages if s['LOS_Terminal_Stage__c']]==['Monitoring']
    transitions = query('SELECT DeveloperName, LOS_From_Stage__r.LOS_Code__c, LOS_To_Stage__r.LOS_Code__c, LOS_Transition_Type__c, LOS_Requires_Reason__c, LOS_Requires_Validation__c, LOS_Active__c FROM LOS_Stage_Transition__mdt')
    expected_edges=set()
    for p in (SOURCE/'customMetadata').glob('LOS_Stage_Transition.*.xml'):
        root=ET.parse(p).getroot()
        values={v.findtext('m:field',namespaces=NS):v.findtext('m:value',namespaces=NS) for v in root.findall('m:values',NS)}
        expected_edges.add((values['LOS_From_Stage__c'],values['LOS_To_Stage__c'],values['LOS_Transition_Type__c']))
    actual_edges={(t['LOS_From_Stage__r']['LOS_Code__c'],t['LOS_To_Stage__r']['LOS_Code__c'],t['LOS_Transition_Type__c']) for t in transitions}
    assert actual_edges==expected_edges and len(transitions)==13
    assert all(t['LOS_Requires_Reason__c'] for t in transitions if t['LOS_Transition_Type__c']=='Rework')
    assert all(t['LOS_Active__c'] and t['LOS_Requires_Validation__c'] for t in transitions)
    types=query('SELECT LOS_Code__c FROM LOS_Application_Type__mdt')
    assert {t['LOS_Code__c'] for t in types}=={'New','Renewal','Modification'}
    names=','.join("'"+o+"'" for o in objects if o.endswith('__c'))
    sharing=query('SELECT QualifiedApiName, InternalSharingModel, ExternalSharingModel FROM EntityDefinition WHERE QualifiedApiName IN ('+names+')',tooling=True)
    assert len(sharing)==9
    assert all(r['InternalSharingModel']=='Private' and r['ExternalSharingModel']=='Private' for r in sharing)
    permissions=query("SELECT Parent.Name, SobjectType, PermissionsRead, PermissionsCreate, PermissionsEdit, PermissionsDelete, PermissionsViewAllRecords, PermissionsModifyAllRecords FROM ObjectPermissions WHERE Parent.Name IN ('LOS_Platform_Admin','LOS_Lending_User')")
    assert len(permissions)==18
    for p in permissions:
        assert p['PermissionsRead']
        assert not any(p[k] for k in ['PermissionsDelete','PermissionsViewAllRecords','PermissionsModifyAllRecords'])
        if p['SobjectType']=='LOS_Lifecycle_History__c': assert not p['PermissionsEdit']
        if p['Parent']['Name']=='LOS_Lending_User' and p['SobjectType'] not in ['LOS_Relationship__c','LOS_Credit_Application__c']:
            assert not p['PermissionsCreate'] and not p['PermissionsEdit']
    units=[]
    if args.expect_reference_data:
        units=query("SELECT LOS_Code__c, LOS_Unit_Type__c, LOS_Parent_Unit__r.LOS_Code__c FROM LOS_Organization_Unit__c WHERE LOS_Code__c LIKE 'REF_%'")
        expected=json.loads((ROOT/'reference-data/organization-units.json').read_text())['records']
        actual={u['LOS_Code__c']:(u['LOS_Unit_Type__c'],u['LOS_Parent_Unit__r']['LOS_Code__c'] if u['LOS_Parent_Unit__r'] else None) for u in units}
        assert actual=={u['LOS_Code__c']:(u['LOS_Unit_Type__c'],u.get('LOS_Parent_Unit__c','')[1:] or None) for u in expected}
    class_names = sorted(p.stem for p in (SOURCE/'classes').glob('*.cls'))
    trigger_names = sorted(p.stem for p in (SOURCE/'triggers').glob('*.trigger'))
    deployed_classes = []
    deployed_triggers = []
    if class_names:
        quoted = ','.join("'"+n+"'" for n in class_names)
        deployed_classes = query('SELECT Name, Status, ApiVersion FROM ApexClass WHERE Name IN ('+quoted+')',tooling=True)
        assert {r['Name'] for r in deployed_classes} == set(class_names)
        assert all(r['Status']=='Active' and r['ApiVersion']==67 for r in deployed_classes)
    if trigger_names:
        quoted = ','.join("'"+n+"'" for n in trigger_names)
        deployed_triggers = query('SELECT Name, Status, ApiVersion FROM ApexTrigger WHERE Name IN ('+quoted+')',tooling=True)
        assert {r['Name'] for r in deployed_triggers} == set(trigger_names)
        assert all(r['Status']=='Active' and r['ApiVersion']==67 for r in deployed_triggers)
    summary={'verifiedAt':datetime.now(timezone.utc).isoformat(),'targetOrgAlias':args.target_org,'status':'Passed','objects':descriptions,'stageCount':len(stages),'transitionCount':len(transitions),'reworkTransitionCount':sum(t['LOS_Transition_Type__c']=='Rework' for t in transitions),'applicationTypes':sorted(t['LOS_Code__c'] for t in types),'privateObjectCount':len(sharing),'objectPermissionCount':len(permissions),'referenceUnitCount':len(units),'apexClassCount':len(deployed_classes),'apexTriggerCount':len(deployed_triggers)}
    Path(args.output).write_text(json.dumps(summary,indent=2)+'\n')
    print(json.dumps(summary,indent=2))

if __name__=='__main__':
    try: main()
    except (AssertionError,RuntimeError,subprocess.TimeoutExpired) as exc:
        print('Verification failed: '+str(exc),file=sys.stderr)
        sys.exit(1)
