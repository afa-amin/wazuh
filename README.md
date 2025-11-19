<div dir="rtl">

# ماژول هوشمند دفاع Wazuh 
تشخیص و واکنش خودکار به حملات Brute-Force، DoS و Spoofing در پروتکل‌های SSH و SMTP

## مقدمه
این ماژول برای Wazuh Manager طراحی شده و با استفاده از قوانین سفارشی، همبستگی پیشرفته (correlation) و اسکریپت‌های Active Response هوشمند، حملات رایج علیه سرویس‌های SSH و SMTP را به صورت بلادرنگ شناسایی و خنثی می‌کند.

ویژگی‌های کلیدی:
- ۲۰ قانون سفارشی با سطح‌بندی دقیق (level 10–15)
- واکنش دو مرحله‌ای هوشمند: Rate-Limit برای حملات معمولی + Block کامل برای حملات شدید
- تشخیص حملات توزیع‌شده، تکرار حمله پس از آنبلاک، و حملات ترکیبی SSH+SMTP
- قرنطینه خودکار فعالیت‌های مشکوک SMTP
- اطلاع‌رسانی فوری به تیم SOC

## پیش‌نیازها
- Wazuh Manager
- دسترسی root یا sudo
- سرویس‌های SSH و Postfix در حال اجرا (برای فعال شدن قوانین)
- سیستم‌عامل لینوکس پشتیبانی‌شده (Debian/Ubuntu، Arch، RHEL/CentOS/Rocky/Alma)

## نصب سریع و کامل

### روش پیشنهادی: اجرای اسکریپت install.sh

این اسکریپت تمام مراحل را به صورت کاملاً خودکار انجام می‌دهد و نیازی به دخالت دستی ندارد.

#### مراحل نصب:
1. تمام فایل‌های پروژه را در یک پوشه قرار دهید (مثلاً /opt/wazuh-smart-defense)
2. وارد پوشه شوید:
   cd /opt/wazuh-smart-defense
3. مجوز اجرایی بدهید:
   chmod +x install.sh
4. اسکریپت را اجرا کنید:
   sudo ./install.sh

#### اسکریپت install.sh دقیقاً چه کارهایی انجام می‌دهد؟

| مرحله | توضیح کامل |
|-------|-------------|
| 0     | تشخیص توزیع لینوکس شما (Debian/Ubuntu، Arch، RHEL و مشتقات) |
| 0     | نصب خودکار تمام وابستگی‌ها: iptables + postfix + sendmail + ipset |
| 1     | بررسی وجود و فعال بودن سرویس wazuh-manager (در صورت عدم وجود یا توقف، نصب متوقف می‌شود) |
| 2     | ساخت دایرکتوری‌های مورد نیاز در مسیر /var/ossec |
| 3     | کپی و تنظیم مالکیت/مجوز فایل ossec.conf (پیکربندی کامل شامل Active Response و ایمیل) |
| 4     | نصب قوانین سفارشی در مسیر /var/ossec/etc/rules/local_rules.xml |
| 5     | نصب اسکریپت‌های Active Response پایتون و شل در مسیر /var/ossec/active-response/bin/:<br>• block-ip.py (بلاک کامل IP)<br>• rate-limit.py (محدودسازی نرخ هوشمند)<br>• quarantine_mail.sh (قرنطینه فعالیت SMTP)<br>• notify_soc.sh (ارسال هشدار به SOC) |
| 6     | راه‌اندازی مجدد امن سرویس wazuh-manager و تأیید موفقیت‌آمیز بودن ری‌استارت |

پس از اتمام، پیام زیر نمایش داده می‌شود:
Wazuh Smart Defense Module Installed!

### نصب دستی
اگر ترجیح می‌دهید همه چیز را خودتان کنترل کنید، می‌توانید فایل‌ها را به صورت دستی کپی کرده و تنظیمات را اعمال کنید. اما به دلیل پیچیدگی پیکربندی Active Response و ossec.conf، استفاده از install.sh به شدت توصیه می‌شود.

## پیکربندی پس از نصب

1. تنظیم ایمیل (اختیاری اما توصیه‌شده)  
   فایل /var/ossec/etc/ossec.conf را باز کنید و بخش global را ویرایش کنید:
   smtp_server → آدرس سرور SMTP سازمان  
   email_from → آدرس فرستنده  
   email_to → آدرس گیرنده هشدارها

2. بررسی قوانین نصب‌شده:
   ls -l /var/ossec/etc/rules/local_rules.xml  
   ls -l /var/ossec/active-response/bin/

3. راه‌اندازی مجدد (در صورت نیاز دستی):
   sudo systemctl restart wazuh-manager

## مشاهده و مانیتورینگ

| مسیر | توضیح |
|------|-------|
| /var/ossec/logs/alerts/alerts.log | تمام هشدارهای Wazuh |
| /var/ossec/logs/block-ip.log | لاگ بلاک و آنبلاک IPها |
| /var/ossec/logs/rate-limit.log | لاگ اعمال Rate-Limit |
| /var/ossec/quarantine/ | فایل‌های قرنطینه فعالیت‌های مشکوک SMTP |
| /var/ossec/soc_alerts.log | هشدارهای ارسالی به تیم SOC |

## رفتار Active Response

| نوع حمله | قانون‌های مرتبط | واکنش خودکار | مدت زمان |
|----------|------------------|---------------|----------|
| Brute-Force معمولی SSH/SMTP | 100002, 100004, 100005, 100008, 100009 | Rate-Limit (۵ درخواست در ثانیه) | ۳۰ دقیقه |
| Brute-Force روی کاربر مدیریتی، DoS شدید، Honeypot | 100003, 100006, 100014, 100017, 100019 | بلاک کامل IP با iptables | ۲۴ ساعت |
| حمله توزیع‌شده یا تکرار پس از آنبلاک | 100013, 100014 | اطلاع‌رسانی فوری به SOC + بلاک ۲۴ ساعته | — |
| Spoofing ایمیل (SPF/DKIM/DMARC fail) | 100012 | قرنطینه فعالیت + ثبت در SOC | — |

## سلامت ماژول
قانون 100099 هر ساعت یک هشدار سطح ۳ تولید می‌کند تا نشان دهد ماژول فعال و سالم است.

## حذف ماژول
- حذف فایل /var/ossec/etc/rules/local_rules.xml
- حذف اسکریپت‌ها از /var/ossec/active-response/bin/
- حذف بخش‌های اضافه‌شده در ossec.conf
- ری‌استارت wazuh-manager
!

</div>
