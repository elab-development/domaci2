<!DOCTYPE html>
<html>

<head>
    <title>Student Data</title>
    <style>
        table {
            width: 100%;
            border-collapse: collapse;
        }

        th,
        td {
            border: 1px solid black;
            padding: 8px;
            text-align: left;
        }

        th {
            background-color: #f2f2f2;
        }
    </style>
</head>

<body>
    <h1>Lista student <?php echo htmlspecialchars($_ENV['APP_FACULTY']); ?></p>
    </h1>
    <table>
        <tr>
            <th>Student ID</th>
            <th>Ime</th>
            <th>Indeks</th>
            <th>Prosek</th>
        </tr>
        <?php
        $file = fopen('data.csv', 'r');
        while (($row = fgetcsv($file)) !== FALSE) {
            echo '<tr>';
            foreach ($row as $cell) {
                echo '<td>' . htmlspecialchars($cell) . '</td>';
            }
            echo '</tr>';
        }
        fclose($file);
        ?>
    </table>
</body>

</html>