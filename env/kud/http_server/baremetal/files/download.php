$fileName = 'my-icn-file.txt';
$filePath = '/var/lib/icn.txt';
if(!$filePath){
    die('File not found!');
} else {
    header("Cache-Control: public");
    header("Content-Disposition: attachment; filename=$fileName");
    header("Content-Type: application/octect-stream");
    header("Content-Transfer-Encoding: binary");
    readfile($filePath);
}
