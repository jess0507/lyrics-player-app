import 'package:flutter/material.dart';

/// 單一國家的撥號碼資料(ISO 3166-1 alpha-2 與 E.164 國碼)。
class DialCode {
  const DialCode(this.name, this.iso, this.code);

  /// 顯示名稱(在地化文字)。
  final String name;

  /// ISO 3166-1 alpha-2 縮寫,例如 `TW`。
  final String iso;

  /// E.164 國碼,含 `+`,例如 `+886`。
  final String code;
}

/// 手機 OTP 支援的國家清單。首項為預設(台灣)。
const kDialCodes = <DialCode>[
  DialCode('台灣', 'TW', '+886'),
  DialCode('中國', 'CN', '+86'),
  DialCode('美國', 'US', '+1'),
  DialCode('英國', 'GB', '+44'),
  DialCode('日本', 'JP', '+81'),
  DialCode('南韓', 'KR', '+82'),
  DialCode('越南', 'VN', '+84'),
  DialCode('印尼', 'ID', '+62'),
  DialCode('印度', 'IN', '+91'),
  DialCode('德國', 'DE', '+49'),
  DialCode('法國', 'FR', '+33'),
  DialCode('西班牙', 'ES', '+34'),
  DialCode('墨西哥', 'MX', '+52'),
  DialCode('義大利', 'IT', '+39'),
  DialCode('葡萄牙', 'PT', '+351'),
  DialCode('巴西', 'BR', '+55'),
  DialCode('俄羅斯', 'RU', '+7'),
  DialCode('土耳其', 'TR', '+90'),
  DialCode('沙烏地阿拉伯', 'SA', '+966'),
];

/// 國碼下拉選單。顯示「ISO 國碼」,選擇後回傳對應的 [DialCode]。
class CountryCodeDropdown extends StatelessWidget {
  const CountryCodeDropdown({
    super.key,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  final DialCode value;
  final ValueChanged<DialCode> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<DialCode>(
      initialValue: value,
      decoration: const InputDecoration(border: OutlineInputBorder()),
      items: [
        for (final c in kDialCodes)
          DropdownMenuItem(value: c, child: Text('${c.iso} ${c.code}')),
      ],
      onChanged: enabled
          ? (c) {
              if (c != null) onChanged(c);
            }
          : null,
    );
  }
}
