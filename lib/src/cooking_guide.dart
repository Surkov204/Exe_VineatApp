typedef CookingInstruction = ({String text, int minutes});

class CookingGuide {
  const CookingGuide(this.seasonings, this.steps);
  final List<String> seasonings;
  final List<CookingInstruction> steps;
}

String _amount(double n) => switch (n) {
  .125 => '1/8',
  .25 => '1/4',
  .5 => '1/2',
  .75 => '3/4',
  1.5 => '1½',
  2.5 => '2½',
  _ =>
    n
        .toStringAsFixed(2)
        .replaceFirst(RegExp(r'\.?0+$'), '')
        .replaceAll('.', ','),
};

// Original culinary reference instructions, scaled to the displayed recipe servings.
// Times are approximate; use doneness checks rather than time alone.
CookingGuide cookingGuide(String name, int servings, List<String> ingredients) {
  final n = servings.toDouble();
  final oil = '${_amount(n)} muỗng cà phê dầu ăn';
  final salt = '${_amount(n / 8)} muỗng cà phê muối';
  final pepper = '${_amount(n / 16)} muỗng cà phê tiêu xay';
  final soy = '${_amount(n / 2)} muỗng cà phê nước tương';
  final garlic = '${_amount(n * 5)} g tỏi băm';
  final water = '${_amount(n * 300)} ml nước';
  const wash = 'Rửa rau sạch, để ráo.';
  if (name.contains('Yến mạch')) {
    final milk = name.contains('sữa đậu nành');
    return CookingGuide(
      [
        'Không cần muối, đường hay dầu ăn',
        milk
            ? '${_amount(n * 200)} ml sữa đậu nành không đường'
            : '${_amount(n * 120)} ml nước nấu yến mạch',
      ],
      [
        (
          text:
              'Đong ${_amount(n * 40)} g yến mạch; bóc $servings quả chuối vừa và cắt lát. ${milk ? 'Đong sữa đậu nành.' : 'Chuẩn bị ${_amount(n * 100)} g sữa chua không đường.'}',
          minutes: 2,
        ),
        (
          text:
              'Cho yến mạch và ${milk ? '${_amount(n * 200)} ml sữa đậu nành' : '${_amount(n * 120)} ml nước'} vào nồi. Đun lửa nhỏ 4–6 phút, khuấy đều; loại yến mạch khác cần theo thời gian trên bao bì. Thêm từng muỗng canh nước nếu quá đặc.',
          minutes: 6,
        ),
        (
          text:
              '${milk ? 'Tắt bếp, chia ra bát.' : 'Để nguội bớt rồi trộn sữa chua, không đun sôi sữa chua.'} Xếp chuối lên trên và dùng. Không cần thêm đường; điều chỉnh độ ngọt bằng lượng chuối.',
          minutes: 2,
        ),
      ],
    );
  }
  if (name.contains('hấp')) {
    return CookingGuide(
      [
        '${_amount(n / 2)} muỗng cà phê nước tương để chấm (tùy chọn)',
        'Không cần dầu ăn',
      ],
      [
        (
          text:
              '$wash Cắt cà rốt lát 0,5 cm, bông cải thành nhánh nhỏ; đậu hũ cắt miếng 2 cm nếu có.',
          minutes: 4,
        ),
        (
          text:
              'Đun nước trong xửng sôi. Hấp cà rốt trước 3 phút, thêm bông cải hoặc đậu hũ rồi hấp 5–7 phút, đến khi rau mềm vừa và đậu hũ nóng đều.',
          minutes: 8,
        ),
        (
          text: 'Cho ra đĩa, chấm với $soy nếu thích. Dùng khi còn nóng.',
          minutes: 2,
        ),
      ],
    );
  }
  if (name.contains('Salad')) {
    final canned = name.contains('cá ngừ');
    return CookingGuide(
      [oil, '$salt và $pepper', '${_amount(n)} muỗng cà phê nước cốt chanh'],
      [
        (
          text:
              '$wash Cắt dưa leo lát mỏng, cà chua miếng vừa ăn; xé xà lách và để thật ráo.',
          minutes: 5,
        ),
        (
          text: canned
              ? 'Dùng cá ngừ hộp ngâm nước đã ráo như định lượng tham khảo; kiểm tra nhãn và hạn dùng. Nếu dùng cá ngừ sống, nấu chín riêng đến nhiệt độ tâm 63°C trước khi trộn.'
              : 'Thấm khô cá, rắc $salt và $pepper. Cho ${_amount(n / 2)} muỗng cà phê dầu ăn vào chảo, áp chảo lửa vừa khoảng 3–5 phút mỗi mặt đến khi chín; kiểm tra tâm cá đạt 63°C. Để nguội bớt, tách miếng.',
          minutes: canned ? 2 : 10,
        ),
        (
          text:
              'Pha ${canned ? oil : '${_amount(n / 2)} muỗng cà phê dầu ăn'} với ${_amount(n)} muỗng cà phê nước cốt chanh${canned ? ', $salt và $pepper' : ''}. Trộn rau trước, thêm cá sau cùng để không nát; dùng ngay.',
          minutes: 3,
        ),
      ],
    );
  }
  if (name.contains('Canh')) {
    final shrimp = ingredients.contains('Tôm sú');
    return CookingGuide(
      [
        water,
        salt,
        pepper,
        '${_amount(n * 5)} g hành lá (nếu có trong nguyên liệu)',
      ],
      [
        (
          text:
              '$wash ${shrimp ? 'Bóc vỏ và bỏ chỉ lưng tôm; không dùng chung thớt với rau.' : 'Cắt đậu hũ miếng 2 cm.'} Cắt rau khúc 3–4 cm; bí đỏ cắt miếng 1–2 cm nếu có.',
          minutes: 5,
        ),
        (
          text:
              'Đun $water sôi. ${name.contains('bí đỏ')
                  ? 'Cho bí đỏ vào, đun nhỏ lửa 10–15 phút đến khi mềm; sau đó thêm đậu hũ và đun 2–3 phút.'
                  : shrimp
                  ? 'Cho tôm vào, nấu đến khi thịt đục và săn; kiểm tra tâm 63°C. Thêm rau, nấu 2–3 phút đến vừa mềm.'
                  : 'Cho đậu hũ vào đun 2–3 phút, thêm rau và nấu thêm 2–3 phút.'}',
          minutes: name.contains('bí đỏ') ? 15 : 8,
        ),
        (
          text:
              'Cho $salt, khuấy nhẹ. Tắt bếp, thêm $pepper và hành lá. Múc ra bát; có thể thêm nước nóng nếu nước canh bị cô đặc. Không nêm thêm muối trước khi nếm.',
          minutes: 2,
        ),
      ],
    );
  }
  if (name.contains('Cá basa')) {
    return CookingGuide(
      [
        oil,
        '${_amount(n)} muỗng cà phê nước mắm',
        '${_amount(n / 2)} muỗng cà phê đường',
        pepper,
        '${_amount(n * 75)} ml nước',
        garlic,
      ],
      [
        (
          text:
              'Thấm khô cá, cắt khúc 2–3 cm. Ướp với ${_amount(n)} muỗng cà phê nước mắm, ${_amount(n / 2)} muỗng cà phê đường, $pepper và ${_amount(n * 2.5)} g tỏi băm trong 10 phút ở tủ lạnh.',
          minutes: 10,
        ),
        (
          text:
              'Làm nóng $oil ở lửa vừa; phi ${_amount(n * 2.5)} g tỏi băm trong 20–30 giây. Cho cá và nước ướp vào, thêm ${_amount(n * 75)} ml nước.',
          minutes: 3,
        ),
        (
          text:
              'Đun sôi rồi giảm lửa, kho 10–15 phút. Trở cá nhẹ một lần; kiểm tra tâm cá đạt 63°C. Nếu khô trước khi cá chín, thêm từng muỗng canh nước nóng.',
          minutes: 12,
        ),
        (
          text:
              'Khi nước kho sánh nhẹ, tắt bếp, thêm hành lá. Không thêm nước mắm nếu đã đủ vị; dùng với phần cơm/rau đã lên kế hoạch.',
          minutes: 2,
        ),
      ],
    );
  }
  if (name.contains('Phở')) {
    return CookingGuide(
      [
        '${_amount(n * 350)} ml nước dùng không nêm sẵn',
        '${_amount(n)} muỗng cà phê nước mắm',
        '${_amount(n / 2)} muỗng cà phê đường',
        'Gừng 2 g/người; quế 0,5 g/người; hồi 0,25 g/người (tùy chọn)',
      ],
      [
        (
          text:
              'Thái bò mỏng ngang thớ. Ngâm/luộc bánh phở khô theo bao bì, xả và để ráo; dùng khối lượng khô ở trên, không áp cho bánh phở tươi.',
          minutes: 6,
        ),
        (
          text:
              'Đun ${_amount(n * 350)} ml nước dùng không nêm sẵn với ${_amount(n * 2)} g gừng, ${_amount(n * .5)} g quế và ${_amount(n * .25)} g hồi trong 10–15 phút. Lọc bỏ gia vị khô, nêm ${_amount(n)} muỗng cà phê nước mắm và ${_amount(n / 2)} muỗng cà phê đường.',
          minutes: 15,
        ),
        (
          text:
              'Cho bò vào nước dùng, nấu chín thay vì chỉ chan nước lên bò sống. Dùng nhiệt kế kiểm tra tâm thịt đạt 63°C và để nghỉ 3 phút; thời gian phụ thuộc độ dày.',
          minutes: 5,
        ),
        (
          text:
              'Chia bánh phở ra bát, thêm bò và hành lá; chan nước dùng nóng. Nước mắm thêm để riêng, không đổ mặc định vào bát.',
          minutes: 2,
        ),
      ],
    );
  }
  if (name.contains('Mì cay')) {
    return CookingGuide(
      [
        '${_amount(n * 350)} ml nước',
        '${_amount(n)} muỗng cà phê nước mắm',
        '${_amount(n / 4)} muỗng cà phê ớt bột (có thể bỏ)',
        'Không dùng thêm gói gia vị nếu đã nêm nước mắm',
      ],
      [
        (
          text:
              'Đun nước sôi; luộc trứng riêng 9–12 phút cho lòng trắng và lòng đỏ đông, rồi bóc vỏ. Trứng lòng đào là tùy chọn nhưng không phù hợp cho người có nguy cơ cao.',
          minutes: 10,
        ),
        (
          text:
              'Đun ${_amount(n * 350)} ml nước, cho ${_amount(n)} muỗng cà phê nước mắm và ${_amount(n / 4)} muỗng cà phê ớt bột (có thể bỏ). Cho mì khô vào, nấu theo bao bì, khuấy nhẹ để không dính. Không thêm gói gia vị khi đã nêm nước mắm.',
          minutes: 5,
        ),
        (
          text:
              'Chia mì ra bát, thêm trứng và hành lá, dùng nóng. Giảm ớt theo khẩu vị; không tự cộng thêm gói nêm mặn.',
          minutes: 2,
        ),
      ],
    );
  }
  if (name.contains('Bánh mì')) {
    return CookingGuide(
      [oil, soy, pepper],
      [
        (
          text:
              'Bổ dọc bánh mì, làm nóng 2–3 phút. Đập từng trứng vào bát riêng để kiểm tra rồi mới cho vào chảo.',
          minutes: 3,
        ),
        (
          text:
              'Đun $oil ở lửa vừa. Cho trứng vào, giảm lửa và đậy nắp đến khi lòng trắng và lòng đỏ đông; không chỉ dựa vào thời gian để xác định chín.',
          minutes: 5,
        ),
        (
          text:
              'Kẹp trứng vào bánh mì, rưới $soy và rắc $pepper, thêm hành lá. Nước tương có độ mặn khác nhau nên có thể dùng ít hơn lượng tham khảo.',
          minutes: 2,
        ),
      ],
    );
  }
  if (name.contains('Cơm gạo lứt')) {
    return CookingGuide(
      [oil, salt, pepper],
      [
        (
          text:
              'Vo ${_amount(n * 50)} g gạo lứt khô, nấu với tỷ lệ nước và thời gian ghi trên bao bì; nhiều loại cần lâu hơn thời gian gợi ý. Rửa dưa leo và cắt lát.',
          minutes: 15,
        ),
        (
          text:
              'Thấm khô gà, ướp $salt và $pepper 5 phút. Làm nóng $oil, áp chảo lửa vừa khoảng 5–7 phút mỗi mặt tùy độ dày; tâm gà phải đạt 74°C.',
          minutes: 12,
        ),
        (
          text:
              'Để gà nghỉ 3 phút rồi thái. Chia cơm, gà và dưa leo theo $servings suất. Không dùng nước ướp gà sống làm nước chấm.',
          minutes: 3,
        ),
      ],
    );
  }
  if (name.contains('Trứng xào')) {
    return CookingGuide(
      [oil, salt, pepper],
      [
        (
          text:
              'Rửa cà chua, cắt múi nhỏ. Đánh tan $servings quả trứng với một nửa $salt. Cắt hành lá; băm tỏi nếu dùng.',
          minutes: 4,
        ),
        (
          text:
              'Cho $oil vào chảo. Xào cà chua và tỏi ở lửa vừa 3–4 phút; thêm ${_amount(n)} muỗng canh nước nếu khô. Cho phần muối còn lại vào.',
          minutes: 4,
        ),
        (
          text:
              'Đổ trứng vào, đảo nhẹ 2–3 phút đến khi đông hoàn toàn; tâm món trứng đạt 71°C. Thêm $pepper và hành lá rồi tắt bếp, dùng nóng.',
          minutes: 3,
        ),
      ],
    );
  }
  final chicken = ingredients.contains('Ức gà');
  final beef = ingredients.any((i) => i.startsWith('Thịt bò'));
  final tofuSauce = name.contains('sốt cà chua');
  final vegetablePrep = [
    if (ingredients.contains('Bông cải xanh')) 'Bông cải cắt nhánh nhỏ.',
    if (ingredients.contains('Cà rốt')) 'Cà rốt cắt lát mỏng.',
    if (ingredients.contains('Cải thảo'))
      'Cải thảo cắt khúc, tách phần cọng và lá.',
    if (ingredients.contains('Dưa leo')) 'Dưa leo cắt lát vừa ăn.',
    if (ingredients.contains('Cà chua')) 'Cà chua cắt nhỏ.',
  ].join(' ');
  return CookingGuide(
    [
      oil,
      '$soy hoặc $salt (chọn một, không cộng cả hai)',
      pepper,
      garlic,
      '${_amount(n * 15)} ml nước',
    ],
    [
      (
        text:
            '$wash ${beef
                ? 'Thái bò mỏng ngang thớ.'
                : chicken
                ? 'Thấm khô gà và cắt miếng 1–2 cm; không rửa gà sống để tránh bắn nước nhiễm khuẩn.'
                : 'Cắt đậu hũ 2 cm nếu có; nấm cắt lát nếu có.'} $vegetablePrep ${beef || chicken ? 'Ướp thịt với $soy hoặc $salt (chọn một), thêm $pepper, để 5 phút.' : ''}',
        minutes: 6,
      ),
      (
        text:
            'Làm nóng $oil; phi $garlic 20–30 giây. ${beef
                ? 'Xào bò lửa vừa-lớn đến chín, kiểm tra tâm 63°C; để nghỉ 3 phút rồi lấy ra.'
                : chicken
                ? 'Xào gà đến chín hoàn toàn, tâm đạt 74°C rồi lấy ra.'
                : tofuSauce
                ? 'Cho cà chua vào xào 3–4 phút đến mềm.'
                : 'Cho đậu hũ vào áp chảo nhẹ nếu có, lấy ra. Nếu có rau củ cứng, xào trước 3–4 phút; rau lá và nấm cho vào sau.'}',
        minutes: 7,
      ),
      (
        text:
            '${tofuSauce ? 'Thêm đậu hũ vào sốt.' : 'Cho rau/nấm còn lại vào chảo.'} Thêm ${_amount(n * 15)} ml nước, đảo 3–5 phút đến rau mềm vừa. ${beef || chicken ? 'Cho thịt đã chín trở lại, đảo thêm 1 phút.' : 'Nêm $soy hoặc $salt (chọn một) cùng $pepper, đảo đều.'}',
        minutes: 5,
      ),
      (
        text:
            'Tắt bếp, thêm hành lá nếu có, chia $servings suất. Nếm trước khi thêm gia vị; có thể dùng ít hơn lượng tham khảo. Dùng khi nóng.',
        minutes: 2,
      ),
    ],
  );
}
