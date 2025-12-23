# Base de Datos Relacional **EduTech Plus**

**Coder:** Vanessa Gómez

------------------------------------------------------------------------

## 1. Descripción del Modelo

El modelo de base de datos diseñado para la empresa **EduTech Plus**
tiene como objetivo gestionar de manera integral la información
académica y administrativa de una institución educativa.

El diseño ha sido implementado en **MySQL**, aplicando reglas de
normalización hasta la **Tercera Forma Normal (3FN)** para garantizar:

-   Integridad de los datos\
-   Eliminación de redundancias\
-   Escalabilidad y mantenimiento del sistema

### Módulos Operativos del Sistema

-   **Académico:** Gestión de programas, periodos académicos y cursos.
-   **Personas:** Administración de perfiles de estudiantes y docentes.
-   **Evaluativo:** Registro detallado de matrículas, evaluaciones
    parciales y calificaciones finales.
-   **Financiero y Auditoría:** Control de pagos, certificaciones y
    trazabilidad de acciones críticas mediante *triggers*.

------------------------------------------------------------------------

## 2. Descripción del Modelo

<img width="2076" height="1086" alt="mermaid-diagram-2025-12-22-231505" src="https://github.com/user-attachments/assets/0e3b8fdc-7d02-41d1-8791-b760727b0ee6" />

------------------------------------------------------------------------

## 3. Script SQL Completo

/* =============================================
   SECCIÓN 1: CREACIÓN DE LA BASE DE DATOS Y TABLAS
   ============================================= */

DROP DATABASE IF EXISTS EduTechPlus;
CREATE DATABASE EduTechPlus CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE EduTechPlus;

-- 1. Tabla Programas Académicos
CREATE TABLE programas_academicos (
    id_programa INT AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    nivel ENUM('Tecnico', 'Tecnologico', 'Pregrado', 'Posgrado') NOT NULL,
    duracion_semestres INT NOT NULL
);

-- 2. Tabla Docentes
CREATE TABLE docentes (
    id_docente INT AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(50) NOT NULL,
    apellido VARCHAR(50) NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    especialidad VARCHAR(100),
    telefono VARCHAR(20)
);

-- 3. Tabla Periodos Académicos
CREATE TABLE periodos_academicos (
    id_periodo INT AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(20) NOT NULL,
    fecha_inicio DATE NOT NULL,
    fecha_fin DATE NOT NULL,
    estado ENUM('Activo', 'Cerrado') DEFAULT 'Activo'
);

-- 4. Tabla Estudiantes
CREATE TABLE estudiantes (
    id_estudiante INT AUTO_INCREMENT PRIMARY KEY,
    documento VARCHAR(20) UNIQUE NOT NULL,
    nombre VARCHAR(50) NOT NULL,
    apellido VARCHAR(50) NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    fecha_nacimiento DATE,
    id_programa INT,
    estado_financiero ENUM('Al dia', 'Mora') DEFAULT 'Al dia',
    FOREIGN KEY (id_programa) REFERENCES programas_academicos(id_programa)
);

-- 5. Tabla Cursos
CREATE TABLE cursos (
    id_curso INT AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    creditos INT NOT NULL CHECK (creditos > 0),
    cupo_maximo INT NOT NULL DEFAULT 30,
    id_docente INT,
    id_programa INT,
    id_periodo INT,
    FOREIGN KEY (id_docente) REFERENCES docentes(id_docente),
    FOREIGN KEY (id_programa) REFERENCES programas_academicos(id_programa),
    FOREIGN KEY (id_periodo) REFERENCES periodos_academicos(id_periodo)
);

-- 6. Tabla Matrículas
CREATE TABLE matriculas (
    id_matricula INT AUTO_INCREMENT PRIMARY KEY,
    id_estudiante INT NOT NULL,
    id_curso INT NOT NULL,
    fecha_matricula DATETIME DEFAULT CURRENT_TIMESTAMP,
    estado ENUM('Cursando', 'Aprobado', 'Reprobado', 'Cancelado') DEFAULT 'Cursando',
    FOREIGN KEY (id_estudiante) REFERENCES estudiantes(id_estudiante),
    FOREIGN KEY (id_curso) REFERENCES cursos(id_curso),
    UNIQUE(id_estudiante, id_curso)
);

-- 7. Tabla Evaluaciones
CREATE TABLE evaluaciones (
    id_evaluacion INT AUTO_INCREMENT PRIMARY KEY,
    id_curso INT NOT NULL,
    nombre VARCHAR(50) NOT NULL,
    porcentaje DECIMAL(5,2) NOT NULL CHECK (porcentaje > 0 AND porcentaje <= 100),
    FOREIGN KEY (id_curso) REFERENCES cursos(id_curso)
);

-- 8. Tabla Calificaciones
CREATE TABLE calificaciones (
    id_calificacion INT AUTO_INCREMENT PRIMARY KEY,
    id_matricula INT NOT NULL,
    id_evaluacion INT NOT NULL,
    nota DECIMAL(3,1) NOT NULL CHECK (nota >= 0 AND nota <= 5.0),
    fecha_registro DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (id_matricula) REFERENCES matriculas(id_matricula),
    FOREIGN KEY (id_evaluacion) REFERENCES evaluaciones(id_evaluacion),
    UNIQUE(id_matricula, id_evaluacion)
);

-- 9. Tabla Pagos
CREATE TABLE pagos (
    id_pago INT AUTO_INCREMENT PRIMARY KEY,
    id_estudiante INT NOT NULL,
    id_periodo INT NOT NULL,
    monto DECIMAL(10,2) NOT NULL,
    fecha_pago DATETIME DEFAULT CURRENT_TIMESTAMP,
    metodo_pago VARCHAR(50),
    FOREIGN KEY (id_estudiante) REFERENCES estudiantes(id_estudiante),
    FOREIGN KEY (id_periodo) REFERENCES periodos_academicos(id_periodo)
);

-- 10. Tabla Certificaciones
CREATE TABLE certificaciones (
    id_certificacion INT AUTO_INCREMENT PRIMARY KEY,
    id_estudiante INT NOT NULL,
    id_periodo INT NOT NULL,
    codigo_verificacion VARCHAR(100) UNIQUE NOT NULL,
    fecha_emision DATE DEFAULT (CURRENT_DATE),
    tipo VARCHAR(50) DEFAULT 'Certificado de Notas',
    FOREIGN KEY (id_estudiante) REFERENCES estudiantes(id_estudiante),
    FOREIGN KEY (id_periodo) REFERENCES periodos_academicos(id_periodo)
);

-- 11. Tabla Auditoría
CREATE TABLE auditoria (
    id_auditoria INT AUTO_INCREMENT PRIMARY KEY,
    tabla_afectada VARCHAR(50),
    accion VARCHAR(50),
    descripcion TEXT,
    usuario_bd VARCHAR(50),
    fecha DATETIME DEFAULT CURRENT_TIMESTAMP
);

/* =============================================
   SECCIÓN 2: TRIGGERS
   ============================================= */
DELIMITER //

-- Trigger 1: Auditoría de Matrículas
CREATE TRIGGER trg_auditoria_matricula
AFTER INSERT ON matriculas
FOR EACH ROW
BEGIN
    INSERT INTO auditoria (tabla_afectada, accion, descripcion, usuario_bd)
    VALUES ('matriculas', 'INSERT', CONCAT('Estudiante ID ', NEW.id_estudiante, ' matriculado en Curso ID ', NEW.id_curso), USER());
END //

-- Trigger 2: Validar Calificación
CREATE TRIGGER trg_validar_nota
BEFORE INSERT ON calificaciones
FOR EACH ROW
BEGIN
    IF NEW.nota < 0 OR NEW.nota > 5 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Error Crítico: La nota debe estar entre 0.0 y 5.0';
    END IF;
END //

-- Trigger 3: Actualizar Estado Financiero
CREATE TRIGGER trg_actualizar_financiero
AFTER INSERT ON pagos
FOR EACH ROW
BEGIN
    UPDATE estudiantes 
    SET estado_financiero = 'Al dia'
    WHERE id_estudiante = NEW.id_estudiante;
END //
DELIMITER ;

/* =============================================
   SECCIÓN 3: PROCEDIMIENTOS ALMACENADOS
   ============================================= */
DELIMITER //

-- SP 1: Registrar Estudiante
CREATE PROCEDURE sp_registrar_estudiante(
    IN p_documento VARCHAR(20), IN p_nombre VARCHAR(50), IN p_apellido VARCHAR(50),
    IN p_email VARCHAR(100), IN p_fecha_nacimiento DATE, IN p_id_programa INT
)
BEGIN
    DECLARE v_existe INT;
    SELECT COUNT(*) INTO v_existe FROM estudiantes WHERE documento = p_documento OR email = p_email;
    IF v_existe > 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Error: Estudiante ya existe.';
    ELSE
        INSERT INTO estudiantes (documento, nombre, apellido, email, fecha_nacimiento, id_programa)
        VALUES (p_documento, p_nombre, p_apellido, p_email, p_fecha_nacimiento, p_id_programa);
    END IF;
END //

-- SP 2: Matricular Estudiante
CREATE PROCEDURE sp_matricular_estudiante(IN p_id_estudiante INT, IN p_id_curso INT)
BEGIN
    INSERT INTO matriculas (id_estudiante, id_curso) VALUES (p_id_estudiante, p_id_curso);
END //

-- SP 3: Registrar Calificación
CREATE PROCEDURE sp_registrar_calificacion(IN p_id_matricula INT, IN p_id_evaluacion INT, IN p_nota DECIMAL(3,1))
BEGIN
    INSERT INTO calificaciones (id_matricula, id_evaluacion, nota)
    VALUES (p_id_matricula, p_id_evaluacion, p_nota)
    ON DUPLICATE KEY UPDATE nota = p_nota;
END //

-- SP 4: Calcular Promedio
CREATE PROCEDURE sp_calcular_promedio(IN p_id_estudiante INT, OUT p_promedio DECIMAL(3,2))
BEGIN
    SELECT IFNULL(AVG(c.nota), 0) INTO p_promedio
    FROM calificaciones c JOIN matriculas m ON c.id_matricula = m.id_matricula
    WHERE m.id_estudiante = p_id_estudiante;
END //

-- SP 5: Generar Certificación
CREATE PROCEDURE sp_generar_certificacion(IN p_id_estudiante INT, IN p_id_periodo INT)
BEGIN
    INSERT INTO certificaciones (id_estudiante, id_periodo, codigo_verificacion)
    VALUES (p_id_estudiante, p_id_periodo, CONCAT('CERT-', UUID_SHORT()));
END //
DELIMITER ;

/* =============================================
   SECCIÓN 4: VISTAS
   ============================================= */

-- Vista 1
CREATE VIEW vw_estudiantes_programa AS
SELECT e.id_estudiante, e.nombre, e.apellido, p.nombre AS programa
FROM estudiantes e JOIN programas_academicos p ON e.id_programa = p.id_programa;

-- Vista 2
CREATE VIEW vw_cursos_docentes AS
SELECT c.nombre AS curso, d.nombre AS docente, pa.nombre AS periodo
FROM cursos c JOIN docentes d ON c.id_docente = d.id_docente
JOIN periodos_academicos pa ON c.id_periodo = pa.id_periodo;

-- Vista 3
CREATE VIEW vw_historial_academico AS
SELECT e.documento, CONCAT(e.nombre, ' ', e.apellido) AS estudiante, c.nombre AS curso, cal.nota
FROM calificaciones cal JOIN matriculas m ON cal.id_matricula = m.id_matricula
JOIN estudiantes e ON m.id_estudiante = e.id_estudiante
JOIN cursos c ON m.id_curso = c.id_curso;

-- Vista 4
CREATE VIEW vw_estado_pagos AS
SELECT e.id_estudiante, e.nombre, SUM(p.monto) AS total_pagado
FROM estudiantes e LEFT JOIN pagos p ON e.id_estudiante = p.id_estudiante
GROUP BY e.id_estudiante, e.nombre;

/* =============================================
   SECCIÓN 5: POBLADO DE DATOS (INSERTS)
   ============================================= */

-- Inserción de Programas, Periodos y Docentes
INSERT INTO programas_academicos (nombre, nivel, duracion_semestres) VALUES 
('Ingeniería de Sistemas', 'Pregrado', 10), ('Administración', 'Pregrado', 9), 
('Desarrollo Web', 'Tecnologico', 6), ('Ciencia de Datos', 'Posgrado', 4), ('Diseño', 'Pregrado', 8);

INSERT INTO periodos_academicos (nombre, fecha_inicio, fecha_fin) VALUES 
('2024-1', '2024-02-01', '2024-06-30'), ('2024-2', '2024-08-01', '2024-12-15');

INSERT INTO docentes (nombre, apellido, email, especialidad) VALUES 
('Carlos', 'Perez', 'cp@edu.com', 'BD'), ('Ana', 'Gomez', 'ag@edu.com', 'Math'), 
('Luis', 'R.', 'lr@edu.com', 'Dev'), ('Maria', 'L.', 'ml@edu.com', 'Scrum'), ('Sofia', 'M.', 'sm@edu.com', 'UX');

-- Inserción de 20 Estudiantes
INSERT INTO estudiantes (documento, nombre, apellido, email, id_programa, estado_financiero) VALUES 
('101', 'Juan', 'Diaz', 'j@m.com', 1, 'Al dia'), ('102', 'Ana', 'Ruiz', 'a@m.com', 1, 'Mora'),
('103', 'Luis', 'Sanz', 'l@m.com', 3, 'Al dia'), ('104', 'Kevin', 'Mina', 'k@m.com', 3, 'Al dia'),
('105', 'Diana', 'Paz', 'd@m.com', 2, 'Al dia'), ('106', 'Andres', 'Cruz', 'an@m.com', 1, 'Mora'),
('107', 'Camila', 'Vela', 'c@m.com', 4, 'Al dia'), ('108', 'Felipe', 'Rios', 'f@m.com', 1, 'Al dia'),
('109', 'Natalia', 'Gil', 'n@m.com', 5, 'Al dia'), ('110', 'Oscar', 'Luna', 'o@m.com', 2, 'Mora'),
('111', 'Valeria', 'Sol', 'v@m.com', 3, 'Al dia'), ('112', 'Jorge', 'Mar', 'jo@m.com', 1, 'Al dia'),
('113', 'Sara', 'Cano', 's@m.com', 4, 'Al dia'), ('114', 'Daniel', 'Roca', 'da@m.com', 5, 'Al dia'),
('115', 'Elena', 'Mora', 'e@m.com', 2, 'Mora'), ('116', 'Victor', 'Pena', 'vi@m.com', 1, 'Al dia'),
('117', 'Gloria', 'Luz', 'g@m.com', 3, 'Al dia'), ('118', 'Hector', 'Sal', 'h@m.com', 2, 'Al dia'),
('119', 'Irene', 'Paz', 'i@m.com', 4, 'Al dia'), ('120', 'Lucas', 'Rey', 'lu@m.com', 1, 'Al dia');

-- Inserción de Cursos
INSERT INTO cursos (nombre, creditos, id_docente, id_programa, id_periodo) VALUES 
('SQL I', 3, 1, 1, 1), ('Logica', 3, 3, 1, 1), ('Discretas', 2, 2, 1, 1), ('Gerencia', 3, 4, 2, 1),
('HTML', 3, 5, 3, 1), ('Big Data', 4, 1, 4, 1), ('UX UI', 3, 5, 5, 1), ('SQL II', 3, 1, 1, 2),
('Java', 3, 3, 3, 2), ('Estadistica', 2, 2, 2, 1);

-- Inserción de Matrículas (Dispara Triggers)
INSERT INTO matriculas (id_estudiante, id_curso) VALUES 
(1, 1), (1, 2), (2, 1), (3, 5), (4, 5), (7, 6), (9, 7), (1, 8), (2, 2), (10, 4);

-- Evaluaciones y Calificaciones
INSERT INTO evaluaciones (id_curso, nombre, porcentaje) VALUES (1, 'Parcial', 40), (1, 'Final', 60), (6, 'Proyecto', 100);
INSERT INTO calificaciones (id_matricula, id_evaluacion, nota) VALUES (1, 1, 4.5), (1, 2, 3.8), (6, 3, 4.8);

-- Pagos
INSERT INTO pagos (id_estudiante, id_periodo, monto) VALUES (1, 1, 500.00), (3, 1, 500.00), (7, 1, 1200.00);

/* =============================================
   SECCIÓN 6: CONSULTAS COMPLEJAS
   ============================================= */

-- 1. Estudiantes con promedio superior al general
SELECT e.nombre, AVG(c.nota) as prom FROM estudiantes e
JOIN matriculas m ON e.id_estudiante = m.id_estudiante
JOIN calificaciones c ON m.id_matricula = c.id_matricula
GROUP BY e.id_estudiante HAVING prom > (SELECT AVG(nota) FROM calificaciones);

-- 2. Cursos más populares
SELECT c.nombre, COUNT(m.id_estudiante) as total FROM cursos c 
LEFT JOIN matriculas m ON c.id_curso = m.id_curso GROUP BY c.id_curso ORDER BY total DESC;

-- 3. Ingresos por periodo
SELECT pa.nombre, SUM(p.monto) FROM periodos_academicos pa JOIN pagos p ON pa.id_periodo = p.id_periodo GROUP BY pa.id_periodo;

-- 4. Estudiantes sin pagos
SELECT e.nombre FROM estudiantes e LEFT JOIN pagos p ON e.id_estudiante = p.id_estudiante WHERE p.id_pago IS NULL;

-- 5. Docentes con más cursos
SELECT d.nombre, COUNT(c.id_curso) as cant FROM docentes d JOIN cursos c ON d.id_docente = c.id_docente GROUP BY d.id_docente ORDER BY cant DESC;

-- 6. Historial Completo
SELECT e.nombre, c.nombre as curso, cal.nota FROM estudiantes e 
JOIN matriculas m ON e.id_estudiante = m.id_estudiante JOIN calificaciones cal ON m.id_matricula = cal.id_matricula JOIN cursos c ON m.id_curso = c.id_curso;

-- 7. Estudiantes que aprobaron todo (Simulado)
SELECT e.nombre FROM estudiantes e JOIN matriculas m ON e.id_estudiante = m.id_estudiante 
JOIN calificaciones c ON m.id_matricula = c.id_matricula GROUP BY e.id_estudiante HAVING MIN(c.nota) >= 3.0;

-- 8. Programas con más estudiantes
SELECT p.nombre, COUNT(DISTINCT e.id_estudiante) as total FROM programas_academicos p 
JOIN estudiantes e ON p.id_programa = e.id_programa WHERE e.id_estudiante IN (SELECT id_estudiante FROM matriculas) GROUP BY p.id_programa ORDER BY total DESC;

-- 9. Clasificación Rendimiento
SELECT e.nombre, CASE WHEN AVG(c.nota) >= 4.5 THEN 'Alto' WHEN AVG(c.nota) >= 3.0 THEN 'Medio' ELSE 'Bajo' END as nivel
FROM estudiantes e JOIN matriculas m ON e.id_estudiante = m.id_estudiante JOIN calificaciones c ON m.id_matricula = c.id_matricula GROUP BY e.id_estudiante;

-- 10. Periodos con altos ingresos (CTE)
WITH Ingresos AS (SELECT id_periodo, SUM(monto) as total FROM pagos GROUP BY id_periodo)
SELECT pa.nombre FROM periodos_academicos pa JOIN Ingresos i ON pa.id_periodo = i.id_periodo WHERE i.total > (SELECT AVG(total) FROM Ingresos);
