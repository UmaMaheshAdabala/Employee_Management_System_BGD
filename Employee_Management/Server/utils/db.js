import mysql from "mysql";
import dotenv from "dotenv";
dotenv.config();

const con = mysql.createConnection({
  host: process.env.DATABASE_ENDPOINT,
  user: process.env.DATABASE_USER,
  password: process.env.DATABASE_PASSWORD,
});

con.connect((err) => {
  if (err) return console.error("Connection error:", err.message);
  console.log("Connected");

  //  Create DB if it doesn't exist
  con.query("CREATE DATABASE IF NOT EXISTS employees_db", (err) => {
    if (err) return console.error("Create DB error:", err.message);
    console.log("Database 'employees_db' is ready");

    // Switch to the new DB
    con.changeUser({ database: "employees_db" }, (err) => {
      if (err) return console.error("Change DB error:", err.message);
      console.log("Using database: employees_db");

      // Create admin table if not exists
      const createAdminTableQuery = `
        CREATE TABLE IF NOT EXISTS admin (
          id INT AUTO_INCREMENT PRIMARY KEY,
          email VARCHAR(100) UNIQUE,
          password VARCHAR(150)
        )
      `;
      con.query(createAdminTableQuery, (err) => {
        if (err) return console.error("Create admin table error:", err.message);
        console.log("Admin table ready");

        // Check if any admin exists
        con.query("SELECT COUNT(*) AS count FROM admin", (err, result) => {
          if (err)
            return console.error("Admin count check error:", err.message);

          const count = result[0].count;
          if (count === 0) {
            const email = "admin1@gmail.com";
            const password = "12345";
            const insertAdminQuery =
              "INSERT INTO admin (email, password) VALUES (?, ?)";
            con.query(insertAdminQuery, [email, password], (err) => {
              if (err) return console.error("Admin insert error:", err.message);
              console.log("Inserted default admin user");
            });
          } else {
            console.log("Admin already exists, no insert performed");
          }
        });
      });

      // Create category table
      const createCategoryQuery = `
        CREATE TABLE IF NOT EXISTS category (
          id INT AUTO_INCREMENT PRIMARY KEY,
          name VARCHAR(30)
        )
      `;
      con.query(createCategoryQuery, (err) => {
        if (err)
          return console.error("Create category table error:", err.message);
        console.log("Category table ready");
      });

      // Create employee table
      const createEmployeeQuery = `
        CREATE TABLE IF NOT EXISTS employee (
          id INT AUTO_INCREMENT PRIMARY KEY,
          name VARCHAR(30),
          email VARCHAR(30),
          password VARCHAR(150),
          salary INT,
          address VARCHAR(40),
          image VARCHAR(50),
          category_id INT,
          FOREIGN KEY (category_id) REFERENCES category(id)
        )
      `;
      con.query(createEmployeeQuery, (err) => {
        if (err)
          return console.error("Create employee table error:", err.message);
        console.log("Employee table ready");
      });
    });
  });
});

export default con;
