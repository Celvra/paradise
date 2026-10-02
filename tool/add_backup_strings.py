#!/usr/bin/env python3
"""Insert the backup strings into each arb file.

The existing humanBackup* wording is reused deliberately: there are two backup
screens in the app and they should not describe the same action two different
ways. Only the keys that have no equivalent there are added here, inserted after
the dataClear block so the settings page reads in order.

Usage: python3 tool/add_backup_strings.py
"""
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# the en entry needs a plural for the conversation count, the others take the
# number as it is
STRINGS = {
    'app_en': [
        ('dataBackup', 'Backup'),
        ('dataBackupExportSub', 'Conversations, cards, stickers and settings'),
        ('dataBackupImportSub', 'From a file you exported before'),
        ('dataBackupRestored', '{chats, plural, =1{1 conversation} other{{chats} conversations}} and {messages} messages'),
        ('dataBackupNothing', 'There was nothing in that file to restore'),
    ],
    'app_zh': [
        ('dataBackup', '备份'),
        ('dataBackupExportSub', '会话、人格卡、表情与设置'),
        ('dataBackupImportSub', '从之前导出的文件恢复'),
        ('dataBackupRestored', '{chats} 个会话，{messages} 条消息'),
        ('dataBackupNothing', '这个文件里没有可恢复的内容'),
    ],
    'app_zh_Hant': [
        ('dataBackup', '備份'),
        ('dataBackupExportSub', '對話、人格卡、表情與設定'),
        ('dataBackupImportSub', '從之前匯出的檔案還原'),
        ('dataBackupRestored', '{chats} 個對話，{messages} 則訊息'),
        ('dataBackupNothing', '這個檔案裡沒有可還原的內容'),
    ],
}

DESCRIPTIONS = {
    'dataBackup': 'Section header above the backup rows',
    'dataBackupExportSub': 'Subtitle of the export row',
    'dataBackupImportSub': 'Subtitle of the import row',
    'dataBackupRestored': 'Bulletin after a restore that changed something',
    'dataBackupNothing': 'Bulletin after a restore that found nothing to do',
}

ANCHOR = '  "@dataClearAllMessage": { "description": '


def main():
    for locale, pairs in STRINGS.items():
        path = os.path.join(ROOT, 'lib', 'l10n', 'arb', f'{locale}.arb')
        with open(path, encoding='utf-8') as fh:
            lines = fh.read().split('\n')
        if any(line.strip().startswith('"dataBackup"') for line in lines):
            print(f'{locale}: already there')
            continue
        at = next((i for i, l in enumerate(lines) if l.startswith(ANCHOR)), None)
        assert at is not None, f'{locale}: no dataClearAllMessage anchor'
        block = []
        for key, value in pairs:
            block.append(f'  "{key}": "{value}",')
            block.append(f'  "@{key}": {{ "description": "{DESCRIPTIONS[key]}" }},')
        lines[at + 1:at + 1] = block
        with open(path, 'w', encoding='utf-8') as fh:
            fh.write('\n'.join(lines))
        print(f'{locale}: inserted after line {at + 1}')


if __name__ == '__main__':
    main()