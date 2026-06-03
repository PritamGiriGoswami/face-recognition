Add-Type -AssemblyName System.Drawing

$root = Resolve-Path (Join-Path $PSScriptRoot '..\..')
$mobileRoot = Resolve-Path (Join-Path $PSScriptRoot '..')

function New-FaceLauncherIcon {
    param(
        [int]$Size,
        [string]$OutputPath
    )

    $bitmap = New-Object System.Drawing.Bitmap $Size, $Size
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $graphics.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
    $graphics.Clear([System.Drawing.Color]::White)

    $scale = $Size / 512.0
    function S([double]$value) { return [single]($value * $scale) }
    function P([double]$x, [double]$y) { return New-Object System.Drawing.PointF (S $x), (S $y) }

    $darkBlue = [System.Drawing.Color]::FromArgb(255, 3, 47, 123)
    $blue = [System.Drawing.Color]::FromArgb(255, 0, 128, 224)
    $lightBlue = [System.Drawing.Color]::FromArgb(255, 0, 178, 255)
    $gray = [System.Drawing.Color]::FromArgb(255, 83, 93, 110)

    $cornerPen = New-Object System.Drawing.Pen $blue, (S 7)
    $cornerPen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
    $cornerPen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
    $cornerPen.LineJoin = [System.Drawing.Drawing2D.LineJoin]::Round

    $meshPen = New-Object System.Drawing.Pen $darkBlue, (S 1.4)
    $facePen = New-Object System.Drawing.Pen $blue, (S 6)
    $facePen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
    $facePen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
    $facePen.LineJoin = [System.Drawing.Drawing2D.LineJoin]::Round
    $beamPen = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(115, 0, 178, 255)), (S 2)
    $beamPen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
    $beamPen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round

    $nodeBrush = New-Object System.Drawing.SolidBrush $blue
    $darkBrush = New-Object System.Drawing.SolidBrush $darkBlue
    $blueBrush = New-Object System.Drawing.SolidBrush $blue
    $grayBrush = New-Object System.Drawing.SolidBrush $gray

    # Scanner corners.
    $graphics.DrawLine($cornerPen, (P 132 62), (P 182 62))
    $graphics.DrawLine($cornerPen, (P 132 62), (P 132 112))
    $graphics.DrawLine($cornerPen, (P 330 62), (P 380 62))
    $graphics.DrawLine($cornerPen, (P 380 62), (P 380 112))
    $graphics.DrawLine($cornerPen, (P 132 282), (P 132 332))
    $graphics.DrawLine($cornerPen, (P 132 332), (P 182 332))
    $graphics.DrawLine($cornerPen, (P 380 282), (P 380 332))
    $graphics.DrawLine($cornerPen, (P 330 332), (P 380 332))

    # Face outline.
    $facePath = New-Object System.Drawing.Drawing2D.GraphicsPath
    $facePath.AddBezier((P 256 78), (P 334 82), (P 352 128), (P 348 184))
    $facePath.AddBezier((P 348 184), (P 370 178), (P 363 225), (P 342 232))
    $facePath.AddBezier((P 342 232), (P 336 286), (P 306 317), (P 266 316))
    $graphics.DrawPath($facePen, $facePath)

    # Half face mesh.
    $mesh = @(
        @(256,78), @(214,91), @(190,116), @(182,150), @(194,184), @(186,218),
        @(203,252), @(216,286), @(247,316), @(266,316), @(244,132), @(242,180),
        @(241,223), @(241,272), @(216,159), @(210,198), @(202,235), @(228,112),
        @(228,249), @(219,212)
    )
    $edges = @(
        @(0,1),@(1,2),@(2,3),@(3,4),@(4,5),@(5,6),@(6,7),@(7,8),@(8,9),
        @(1,17),@(17,10),@(10,0),@(17,2),@(2,14),@(14,10),@(14,4),
        @(4,15),@(15,11),@(11,10),@(11,19),@(19,18),@(18,7),@(7,16),
        @(16,6),@(16,5),@(15,16),@(18,12),@(12,11),@(12,13),@(13,9),
        @(8,13),@(3,14)
    )
    foreach ($edge in $edges) {
        $a = $mesh[$edge[0]]
        $b = $mesh[$edge[1]]
        $graphics.DrawLine($meshPen, (P $a[0] $a[1]), (P $b[0] $b[1]))
    }
    foreach ($point in $mesh) {
        $graphics.FillEllipse($nodeBrush, (S ($point[0] - 3.2)), (S ($point[1] - 3.2)), (S 6.4), (S 6.4))
    }

    # Scan beam, eye, nose, mouth.
    $graphics.DrawLine($beamPen, (P 142 185), (P 370 185))
    $graphics.FillEllipse($blueBrush, (S 286), (S 174), (S 18), (S 12))
    $graphics.DrawArc($facePen, (S 272), (S 158), (S 48), (S 28), 205, 130)
    $graphics.DrawArc($facePen, (S 257), (S 218), (S 42), (S 38), 40, 96)
    $graphics.DrawArc($facePen, (S 248), (S 245), (S 56), (S 20), 190, 150)
    $graphics.DrawArc($facePen, (S 259), (S 268), (S 34), (S 14), 15, 150)

    # Text lockup from the supplied logo.
    $faceFont = New-Object System.Drawing.Font 'Arial', (S 50), ([System.Drawing.FontStyle]::Bold)
    $recFont = New-Object System.Drawing.Font 'Arial', (S 19), ([System.Drawing.FontStyle]::Bold)
    $sysFont = New-Object System.Drawing.Font 'Arial', (S 15), ([System.Drawing.FontStyle]::Bold)
    $centerFormat = New-Object System.Drawing.StringFormat
    $centerFormat.Alignment = [System.Drawing.StringAlignment]::Center
    $centerFormat.LineAlignment = [System.Drawing.StringAlignment]::Center

    $graphics.DrawString('FACE', $faceFont, $darkBrush, (New-Object System.Drawing.RectangleF 0, (S 350), $Size, (S 58)), $centerFormat)
    $graphics.FillEllipse($blueBrush, (S 223), (S 387), (S 13), (S 13))
    $graphics.DrawString('R E C O G N I T I O N', $recFont, $blueBrush, (New-Object System.Drawing.RectangleF 0, (S 410), $Size, (S 32)), $centerFormat)
    $graphics.DrawLine((New-Object System.Drawing.Pen $darkBlue, (S 1.8)), (P 135 457), (P 196 457))
    $graphics.DrawString('S Y S T E M', $sysFont, $grayBrush, (New-Object System.Drawing.RectangleF 0, (S 447), $Size, (S 28)), $centerFormat)
    $graphics.DrawLine((New-Object System.Drawing.Pen $darkBlue, (S 1.8)), (P 318 457), (P 377 457))

    $directory = Split-Path $OutputPath -Parent
    if (!(Test-Path $directory)) {
        New-Item -ItemType Directory -Path $directory | Out-Null
    }
    $bitmap.Save($OutputPath, [System.Drawing.Imaging.ImageFormat]::Png)

    $graphics.Dispose()
    $bitmap.Dispose()
}

$outputs = @(
    @{ Size = 48; Path = Join-Path $mobileRoot 'android\app\src\main\res\mipmap-mdpi\ic_launcher.png' },
    @{ Size = 72; Path = Join-Path $mobileRoot 'android\app\src\main\res\mipmap-hdpi\ic_launcher.png' },
    @{ Size = 96; Path = Join-Path $mobileRoot 'android\app\src\main\res\mipmap-xhdpi\ic_launcher.png' },
    @{ Size = 144; Path = Join-Path $mobileRoot 'android\app\src\main\res\mipmap-xxhdpi\ic_launcher.png' },
    @{ Size = 192; Path = Join-Path $mobileRoot 'android\app\src\main\res\mipmap-xxxhdpi\ic_launcher.png' },
    @{ Size = 192; Path = Join-Path $mobileRoot 'web\icons\Icon-192.png' },
    @{ Size = 512; Path = Join-Path $mobileRoot 'web\icons\Icon-512.png' },
    @{ Size = 192; Path = Join-Path $mobileRoot 'web\icons\Icon-maskable-192.png' },
    @{ Size = 512; Path = Join-Path $mobileRoot 'web\icons\Icon-maskable-512.png' },
    @{ Size = 48; Path = Join-Path $root 'generated_launcher\ic_launcher_48.png' },
    @{ Size = 72; Path = Join-Path $root 'generated_launcher\ic_launcher_72.png' },
    @{ Size = 96; Path = Join-Path $root 'generated_launcher\ic_launcher_96.png' },
    @{ Size = 144; Path = Join-Path $root 'generated_launcher\ic_launcher_144.png' },
    @{ Size = 192; Path = Join-Path $root 'generated_launcher\ic_launcher_192.png' },
    @{ Size = 256; Path = Join-Path $root 'generated_launcher\ic_launcher_256.png' },
    @{ Size = 384; Path = Join-Path $root 'generated_launcher\ic_launcher_384.png' },
    @{ Size = 512; Path = Join-Path $root 'generated_launcher\ic_launcher_512.png' }
)

foreach ($output in $outputs) {
    New-FaceLauncherIcon -Size $output.Size -OutputPath $output.Path
}

Write-Host "Generated face recognition launcher icons."
