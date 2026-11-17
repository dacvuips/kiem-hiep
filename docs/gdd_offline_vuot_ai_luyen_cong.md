# TÀI LIỆU ĐẶC TẢ THIẾT KẾ GAME (GAME DESIGN DOCUMENT - GDD)
## ĐẶC TẢ TÍNH NĂNG OFFLINE – VƯỢT ẢI LUYỆN CÔNG
### Định hướng gameplay: Survival Action – kết hợp hệ thống môn phái của JX1 Võ Lâm Truyền Kỳ

---

## 1. Tổng quan gameplay
Xây dựng chế độ Offline – Vượt Ải Luyện Công theo phong cách game Survivor.
Người chơi sẽ tham gia vào từng bản đồ chiến đấu, nơi quái vật liên tục được sinh ra theo từng đợt và tự động truy đuổi nhân vật. Nhiệm vụ của người chơi là di chuyển, né tránh, tiêu diệt quái vật, thu thập EXP và liên tục nâng cấp kỹ năng để sinh tồn.

Điểm cốt lõi của chế độ này là kết hợp:
- Cơ chế quái vật sinh liên tục và truy đuổi người chơi.
- Hệ thống kỹ năng chiến đấu đặc trưng của từng môn phái JX1.
- Cơ chế Level Up và nâng cấp kỹ năng theo phong cách Survivor.
- Hệ thống bản đồ, cấp độ thử thách và xếp hạng 3 sao.

---

## 2. Hệ thống môn phái và nhân vật
- Khi người chơi mới tham gia game, hệ thống sẽ yêu cầu lựa chọn môn phái theo hệ phái mà người chơi mong muốn.
- Môn phái đã chọn sẽ được gắn cố định với nhân vật, không thay đổi trong quá trình tham gia chế độ này.
- Toàn bộ kỹ năng chiến đấu xuất hiện trong quá trình Level Up phải thuộc danh sách kỹ năng của môn phái mà nhân vật đã chọn.
- Mỗi môn phái cần có bộ kỹ năng, hiệu ứng tấn công và phong cách chiến đấu riêng biệt, đảm bảo sự khác biệt giữa các hệ phái.

---

## 3. Hệ thống cấp độ và bản đồ Vượt Ải

### 3.1. Điều kiện tham gia
- Phân chia bản đồ theo từng mốc cấp độ nhân vật: 1x, 2x, 3x, 4x...
- Người chơi chỉ được tham gia bản đồ tương ứng với cấp độ mà nhân vật đã đạt.
- *Ví dụ:* Nhân vật cấp 1x chỉ được tham gia khu vực 1x, không thể tham gia khu vực 2x khi chưa đủ điều kiện.
- Các mốc cấp độ phải được phân chia rõ ràng nhằm tạo tiến trình thử thách và phát triển nhân vật.

### 3.2. Cấu trúc bản đồ
- Mỗi mốc cấp độ chỉ thiết kế tối đa 3 bản đồ.
- Mỗi bản đồ phải có hệ thống quái vật đặc trưng, phù hợp với bối cảnh và đặc điểm của bản đồ đó.
- Ba bản đồ được sắp xếp theo thứ tự thử thách, người chơi phải hoàn thành bản đồ trước mới được mở khóa bản đồ tiếp theo.
- Điều kiện hoàn thành bản đồ là tiêu diệt được quái vật cuối cùng (Boss hoặc quái tinh anh cuối ải).
- Sau khi hoàn thành, hệ thống ghi nhận kết quả và cho phép người chơi tiếp tục tiến vào bản đồ kế tiếp.

---

## 4. Hệ thống đánh giá hoàn thành – 3 sao
Mỗi bản đồ sẽ có hệ thống đánh giá thành tích tối đa 3 sao.
Để đạt được 3 sao, người chơi phải đồng thời đáp ứng các điều kiện:
1. **Thời gian hoàn thành:** Tiêu diệt đợt quái cuối cùng trong giới hạn thời gian quy định.
2. **Điểm thành tích:** Đạt mức điểm yêu cầu của bản đồ.
3. **Số lượng tiêu diệt:** Tiêu diệt đủ số lượng quái vật theo yêu cầu.

Hệ thống sẽ căn cứ vào kết quả thực tế để đánh giá và trao số sao tương ứng.
Mục tiêu là khuyến khích người chơi không chỉ hoàn thành bản đồ mà còn tối ưu tốc độ chiến đấu, khả năng sinh tồn và hiệu suất tiêu diệt quái.

---

## 5. Hệ thống kỹ năng – Skill Level Up
Đây là tính năng cốt lõi của chế độ Survivor, cần được đầu tư kỹ về gameplay và UI/UX.

### 5.1. Lựa chọn kỹ năng ban đầu
- Ngay khi bắt đầu một màn chơi, người chơi được mở giao diện lựa chọn kỹ năng lần đầu.
- Kỹ năng được đề xuất phải thuộc bộ kỹ năng chiến đấu của môn phái đã chọn.
- Người chơi lựa chọn một kỹ năng khởi đầu để sử dụng trong suốt quá trình vượt ải.

### 5.2. Cơ chế xuất hiện kỹ năng khi Level Up
- Khi nhân vật thu thập đủ EXP và lên cấp, hệ thống sẽ hiển thị giao diện Level Up.
- Hệ thống chỉ sử dụng 6 kỹ năng chiến đấu được chọn ngẫu nhiên từ danh sách kỹ năng của môn phái.
- Sáu kỹ năng này tạo thành nhóm kỹ năng xuất hiện xuyên suốt quá trình nâng cấp trong màn chơi.
- Mỗi lần Level Up, hệ thống hiển thị ngẫu nhiên 3 kỹ năng để người chơi lựa chọn.
- Người chơi chỉ được chọn 1 trong 3 kỹ năng được đề xuất.
- Cơ chế lựa chọn này được duy trì xuyên suốt quá trình lên cấp, tạo sự đa dạng trong mỗi lượt chơi.

### 5.3. Cơ chế nâng cấp kỹ năng theo sao
Mỗi kỹ năng có tối đa 5 cấp sao:
- **1 sao:** Cấp kỹ năng cơ bản.
- **2 sao:** Nâng cấp lần thứ nhất.
- **3 sao:** Nâng cấp lần thứ hai.
- **4 sao:** Nâng cấp lần thứ ba.
- **5 sao:** Đạt cấp nâng cấp tối đa.

Khi người chơi tiếp tục lựa chọn một kỹ năng đã sở hữu, kỹ năng đó sẽ được tăng thêm 1 sao.
Việc nâng cấp phải tạo ra sự thay đổi rõ rệt về sức mạnh, số lượng chiêu thức và hiệu quả chiến đấu.

### 5.4. Cơ chế tăng số lượng chiêu thức theo sao
Đây là yêu cầu quan trọng cần được áp dụng thống nhất cho toàn bộ kỹ năng.
Khi nâng cấp sao, số lượng chiêu thức được phóng ra phải tăng theo cấp sao và dựa trên số lượng chiêu thức hiện tại của kỹ năng.

| Cấp sao | Số lượng chiêu thức |
| :---: | :---: |
| 1 sao | 1 kiếm |
| 2 sao | 2 kiếm |
| 3 sao | 3 kiếm |
| 4 sao | 4 kiếm |
| 5 sao | 5 kiếm |

**Công thức đề xuất:**
$$Số\ chiêu\ thức = Số\ lượng\ cơ\ bản \times Cấp\ sao$$
*Ví dụ:* 8 kiếm ở 1 sao $\rightarrow$ 16 kiếm ở 2 sao $\rightarrow$ 24 kiếm ở 3 sao $\rightarrow$ 32 kiếm ở 4 sao $\rightarrow$ 40 kiếm ở 5 sao.

---

## 6. Hệ thống ngọc EXP rơi ra từ quái vật
Khi quái vật bị tiêu diệt, chúng sẽ có tỷ lệ rơi ra các viên ngọc EXP. Người chơi di chuyển đến vị trí viên ngọc để thu thập và nhận EXP tương ứng.
Thiết kế 3 loại ngọc với phong cách đồ họa Fantasy – Võ Lâm, phù hợp với gameplay Survivor:

1. **Ngọc EXP nhỏ:** EXP cơ bản – quái thường (Màu lục vàng, kích thước tiêu chuẩn).
2. **Ngọc EXP trung:** EXP trung bình – quái tinh anh (Màu lam tinh anh, kích thước lớn hơn x1.6).
3. **Ngọc EXP lớn:** EXP cao – Boss và quái đặc biệt (Màu đỏ hoàng kim, kích thước x2.5, phát sáng mạnh).

**Yêu cầu chức năng:**
- Ngọc phải có hiệu ứng phát sáng/nhấp nháy để người chơi dễ nhận diện trên bản đồ.
- Mỗi loại ngọc có màu sắc, kích thước và hiệu ứng riêng biệt.
- Khi người chơi đến gần, ngọc có thể tự động hút về nhân vật theo bán kính thu thập (`pickup_radius`).
- Khi thu thập, ngọc biến mất và cộng EXP trực tiếp vào thanh kinh nghiệm trong trận.
- Khi đủ EXP, kích hoạt cơ chế Level Up ngay lập tức (tạm dừng hoặc chậm chuyển động để chọn thẻ bài).

---

## 7. Yêu cầu tổng thể đối với đội ngũ phát triển

| Hạng mục | Yêu cầu |
| :--- | :--- |
| **Gameplay** | Quái sinh liên tục theo đợt, tự động truy đuổi người chơi |
| **Môn phái** | Kỹ năng chính tông theo từng môn phái JX1 |
| **Bản đồ** | Tối đa 3 bản đồ cho mỗi mốc cấp (1x, 2x, 3x, 4x...) |
| **Tiến trình** | Hoàn thành lần lượt từng bản đồ, hạ Boss mở khóa tiếp theo |
| **Đánh giá** | Hệ thống xếp hạng 1–3 sao (Thời gian, Điểm số, Số quái hạ) |
| **Level Up** | Mỗi lần lên cấp hiển thị 3 lựa chọn thẻ bài kỹ năng |
| **Bộ kỹ năng** | Tối đa 6 kỹ năng trong một lượt chơi |
| **Nâng cấp** | Mỗi kỹ năng tối đa 5 sao (1⭐ đến 5⭐) |
| **EXP** | 3 loại ngọc rơi ra từ quái vật (Nhỏ / Trung / Lớn) |

### Định hướng trải nghiệm cuối cùng
Chế độ Vượt Ải Luyện Công mang lại cảm giác chiến đấu liên tục, đông quái, kỹ năng tung ra dồn dập và sức mạnh nhân vật tăng tiến rõ rệt theo từng lần Level Up.
Đặc biệt, giữ nguyên bản sắc kỹ năng của JX1 Võ Lâm Truyền Kỳ, nhưng chuyển đổi cơ chế thi triển sang phong cách Survivor. Người chơi cảm nhận được sự quen thuộc của môn phái, đồng thời có trải nghiệm sinh tồn, nâng cấp và càn quét quái vật hoàn toàn mới.
