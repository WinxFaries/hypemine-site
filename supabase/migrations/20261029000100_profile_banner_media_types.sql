-- Enable optimized image, animated image, and MP4 profile banners.
-- Run once after the base HypeMine avatar bucket has been created.
update storage.buckets
set file_size_limit = 10485760,
    allowed_mime_types = array[
      'image/webp',
      'image/jpeg',
      'image/png',
      'image/gif',
      'image/avif',
      'image/apng',
      'video/mp4'
    ]
where id = 'hm-avatars';
