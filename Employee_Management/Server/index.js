import express from "express";
import cors from "cors";
import { adminRouter } from "./Routes/AdminRoute.js";
import { EmployeeRouter } from "./Routes/EmployeeRoute.js";
import Jwt from "jsonwebtoken";
import cookieParser from "cookie-parser";
import dotenv from "dotenv";
import path from "path";
import { fileURLToPath } from "url";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

dotenv.config();

const app = express();
app.use(
  cors({
    origin: [process.env.FRONTEND_URL],
    methods: ["GET", "POST", "PUT", "DELETE"],
    credentials: true,
  })
);
app.use(express.json());
app.use(cookieParser());
app.use("/api/auth", adminRouter);
app.use("/api/employee", EmployeeRouter);
app.use(express.static("Public"));
app.use("/Images", express.static(path.join(__dirname, "Public/Images")));

const verifyUser = (req, res, next) => {
  const token = req.cookies.token;
  if (token) {
    Jwt.verify(token, "jwt_secret_key", (err, decoded) => {
      if (err) return res.json({ Status: false, Error: "Wrong Token" });
      req.id = decoded.id;
      req.role = decoded.role;
      next();
    });
  } else {
    return res.json({ Status: false, Error: "Not autheticated" });
  }
};

app.get("/api/health", (req, res) => {
  console.log("Health Check OK");
  console.log("Blue Env");
  res.status(200).send("OK");
});

app.get("/api/verify", verifyUser, (req, res) => {
  return res.json({ Status: true, role: req.role, id: req.id });
});

app.listen(3000, "0.0.0.0", () => {
  console.log("Server is running");
});
