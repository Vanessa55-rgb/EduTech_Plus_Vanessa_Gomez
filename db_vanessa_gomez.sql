-- phpMyAdmin SQL Dump
-- version 5.2.2
-- https://www.phpmyadmin.net/
--
-- Servidor: mysql
-- Tiempo de generación: 23-12-2025 a las 04:19:55
-- Versión del servidor: 8.0.43
-- Versión de PHP: 8.2.27

SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
START TRANSACTION;
SET time_zone = "+00:00";


/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;

--
-- Base de datos: `db_vanessa_gomez`
--

DELIMITER $$
--
-- Procedimientos
--
CREATE DEFINER=`root`@`%` PROCEDURE `sp_calcular_promedio` (IN `p_id_estudiante` INT, OUT `p_promedio` DECIMAL(3,2))   BEGIN
    SELECT IFNULL(AVG(c.nota), 0)
    INTO p_promedio
    FROM calificaciones c
    JOIN matriculas m ON c.id_matricula = m.id_matricula
    WHERE m.id_estudiante = p_id_estudiante;
END$$

CREATE DEFINER=`root`@`%` PROCEDURE `sp_generar_certificacion` (IN `p_id_estudiante` INT, IN `p_id_periodo` INT)   BEGIN
    DECLARE v_cursos_aprobados INT;
    DECLARE v_codigo VARCHAR(100);
    
    -- Verificar si tiene cursos aprobados en ese periodo (Nota > 3.0 por simplicidad)
    SELECT COUNT(*) INTO v_cursos_aprobados
    FROM matriculas m
    JOIN calificaciones c ON m.id_matricula = c.id_matricula
    JOIN cursos cur ON m.id_curso = cur.id_curso
    WHERE m.id_estudiante = p_id_estudiante 
      AND cur.id_periodo = p_id_periodo
      AND c.nota >= 3.0; -- Simplificación: verifica si tiene al menos notas aprobatorias

    IF v_cursos_aprobados = 0 THEN
         SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Error: El estudiante no tiene cursos aprobados para generar certificado.';
    ELSE
        -- Generar código único
        SET v_codigo = CONCAT('CERT-', p_id_estudiante, '-', p_id_periodo, '-', UUID_SHORT());
        
        INSERT INTO certificaciones (id_estudiante, id_periodo, codigo_verificacion)
        VALUES (p_id_estudiante, p_id_periodo, v_codigo);
        
        SELECT CONCAT('Certificación generada exitosamente. Código: ', v_codigo) AS Mensaje;
    END IF;
END$$

CREATE DEFINER=`root`@`%` PROCEDURE `sp_matricular_estudiante` (IN `p_id_estudiante` INT, IN `p_id_curso` INT)   BEGIN
    DECLARE v_cupo_actual INT;
    DECLARE v_cupo_max INT;
    
    -- Validaciones básicas
    IF NOT EXISTS (SELECT 1 FROM estudiantes WHERE id_estudiante = p_id_estudiante) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Error: Estudiante no encontrado.';
    END IF;

    IF EXISTS (SELECT 1 FROM matriculas WHERE id_estudiante = p_id_estudiante AND id_curso = p_id_curso) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Error: El estudiante ya está matriculado en este curso.';
    END IF;

    -- Validar Cupo
    SELECT cupo_maximo INTO v_cupo_max FROM cursos WHERE id_curso = p_id_curso;
    SELECT COUNT(*) INTO v_cupo_actual FROM matriculas WHERE id_curso = p_id_curso;

    IF v_cupo_actual >= v_cupo_max THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Error: No hay cupo disponible en el curso.';
    ELSE
        INSERT INTO matriculas (id_estudiante, id_curso) VALUES (p_id_estudiante, p_id_curso);
    END IF;
END$$

CREATE DEFINER=`root`@`%` PROCEDURE `sp_registrar_calificacion` (IN `p_id_matricula` INT, IN `p_id_evaluacion` INT, IN `p_nota` DECIMAL(3,1))   BEGIN
    -- Validar rango nota
    IF p_nota < 0 OR p_nota > 5.0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Error: La nota debe estar entre 0.0 y 5.0';
    END IF;

    -- Validar existencia de matricula y evaluación
    IF NOT EXISTS (SELECT 1 FROM matriculas WHERE id_matricula = p_id_matricula) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Error: Matrícula no válida.';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM evaluaciones WHERE id_evaluacion = p_id_evaluacion) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Error: Evaluación no encontrada.';
    END IF;

    -- Insertar o actualizar (Upsert)
    INSERT INTO calificaciones (id_matricula, id_evaluacion, nota)
    VALUES (p_id_matricula, p_id_evaluacion, p_nota)
    ON DUPLICATE KEY UPDATE nota = p_nota, fecha_registro = NOW();
END$$

CREATE DEFINER=`root`@`%` PROCEDURE `sp_registrar_estudiante` (IN `p_documento` VARCHAR(20), IN `p_nombre` VARCHAR(50), IN `p_apellido` VARCHAR(50), IN `p_email` VARCHAR(100), IN `p_fecha_nacimiento` DATE, IN `p_id_programa` INT)   BEGIN
    DECLARE v_existe INT;

    -- Validar duplicados
    SELECT COUNT(*) INTO v_existe FROM estudiantes WHERE documento = p_documento OR email = p_email;
    
    IF v_existe > 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Error: El estudiante ya existe (Documento o Email duplicado).';
    ELSE
        -- Validar programa
        IF NOT EXISTS (SELECT 1 FROM programas_academicos WHERE id_programa = p_id_programa) THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Error: El programa académico no existe.';
        ELSE
            INSERT INTO estudiantes (documento, nombre, apellido, email, fecha_nacimiento, id_programa)
            VALUES (p_documento, p_nombre, p_apellido, p_email, p_fecha_nacimiento, p_id_programa);
        END IF;
    END IF;
END$$

DELIMITER ;

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `auditoria`
--

CREATE TABLE `auditoria` (
  `id_auditoria` int NOT NULL,
  `tabla_afectada` varchar(50) DEFAULT NULL,
  `accion` varchar(50) DEFAULT NULL,
  `descripcion` text,
  `usuario_bd` varchar(50) DEFAULT NULL,
  `fecha` datetime DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

--
-- Volcado de datos para la tabla `auditoria`
--

INSERT INTO `auditoria` (`id_auditoria`, `tabla_afectada`, `accion`, `descripcion`, `usuario_bd`, `fecha`) VALUES
(1, 'matriculas', 'INSERT', 'Estudiante ID 1 matriculado en Curso ID 1', 'root@172.18.0.3', '2025-12-23 03:34:03'),
(2, 'matriculas', 'INSERT', 'Estudiante ID 1 matriculado en Curso ID 2', 'root@172.18.0.3', '2025-12-23 03:34:03'),
(3, 'matriculas', 'INSERT', 'Estudiante ID 2 matriculado en Curso ID 1', 'root@172.18.0.3', '2025-12-23 03:34:03'),
(4, 'matriculas', 'INSERT', 'Estudiante ID 3 matriculado en Curso ID 5', 'root@172.18.0.3', '2025-12-23 03:34:03'),
(5, 'matriculas', 'INSERT', 'Estudiante ID 4 matriculado en Curso ID 5', 'root@172.18.0.3', '2025-12-23 03:34:03'),
(6, 'matriculas', 'INSERT', 'Estudiante ID 7 matriculado en Curso ID 6', 'root@172.18.0.3', '2025-12-23 03:34:03'),
(7, 'matriculas', 'INSERT', 'Estudiante ID 9 matriculado en Curso ID 7', 'root@172.18.0.3', '2025-12-23 03:34:03'),
(8, 'matriculas', 'INSERT', 'Estudiante ID 1 matriculado en Curso ID 8', 'root@172.18.0.3', '2025-12-23 03:34:03'),
(9, 'matriculas', 'INSERT', 'Estudiante ID 2 matriculado en Curso ID 2', 'root@172.18.0.3', '2025-12-23 03:34:03'),
(10, 'matriculas', 'INSERT', 'Estudiante ID 10 matriculado en Curso ID 4', 'root@172.18.0.3', '2025-12-23 03:34:03');

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `calificaciones`
--

CREATE TABLE `calificaciones` (
  `id_calificacion` int NOT NULL,
  `id_matricula` int NOT NULL,
  `id_evaluacion` int NOT NULL,
  `nota` decimal(3,1) NOT NULL,
  `fecha_registro` datetime DEFAULT CURRENT_TIMESTAMP
) ;

--
-- Volcado de datos para la tabla `calificaciones`
--

INSERT INTO `calificaciones` (`id_calificacion`, `id_matricula`, `id_evaluacion`, `nota`, `fecha_registro`) VALUES
(1, 1, 1, 4.5, '2025-12-23 03:34:03'),
(2, 1, 2, 3.8, '2025-12-23 03:34:03'),
(3, 1, 3, 5.0, '2025-12-23 03:34:03'),
(4, 3, 1, 2.0, '2025-12-23 03:34:03'),
(5, 3, 2, 2.5, '2025-12-23 03:34:03'),
(6, 3, 3, 3.0, '2025-12-23 03:34:03'),
(7, 6, 5, 4.8, '2025-12-23 03:34:03');

--
-- Disparadores `calificaciones`
--
DELIMITER $$
CREATE TRIGGER `trg_validar_nota` BEFORE INSERT ON `calificaciones` FOR EACH ROW BEGIN
    IF NEW.nota < 0 OR NEW.nota > 5 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Error Crítico: La nota está fuera del rango permitido (0-5).';
    END IF;
END
$$
DELIMITER ;

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `certificaciones`
--

CREATE TABLE `certificaciones` (
  `id_certificacion` int NOT NULL,
  `id_estudiante` int NOT NULL,
  `id_periodo` int NOT NULL,
  `codigo_verificacion` varchar(100) NOT NULL,
  `fecha_emision` date DEFAULT (curdate()),
  `tipo` varchar(50) DEFAULT 'Certificado de Notas'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `cursos`
--

CREATE TABLE `cursos` (
  `id_curso` int NOT NULL,
  `nombre` varchar(100) NOT NULL,
  `creditos` int NOT NULL,
  `cupo_maximo` int NOT NULL DEFAULT '30',
  `id_docente` int DEFAULT NULL,
  `id_programa` int DEFAULT NULL,
  `id_periodo` int DEFAULT NULL
) ;

--
-- Volcado de datos para la tabla `cursos`
--

INSERT INTO `cursos` (`id_curso`, `nombre`, `creditos`, `cupo_maximo`, `id_docente`, `id_programa`, `id_periodo`) VALUES
(1, 'Base de Datos I', 3, 30, 1, 1, 1),
(2, 'Algoritmos', 3, 30, 3, 1, 1),
(3, 'Matematicas Discretas', 2, 30, 2, 1, 1),
(4, 'Gerencia', 3, 30, 4, 2, 1),
(5, 'Diseño Web', 3, 30, 5, 3, 1),
(6, 'Big Data', 4, 30, 1, 4, 1),
(7, 'Taller de Diseño', 3, 30, 5, 5, 1),
(8, 'Base de Datos II', 3, 30, 1, 1, 2),
(9, 'POO', 3, 30, 3, 3, 2),
(10, 'Estadistica', 2, 30, 2, 2, 1);

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `docentes`
--

CREATE TABLE `docentes` (
  `id_docente` int NOT NULL,
  `nombre` varchar(50) NOT NULL,
  `apellido` varchar(50) NOT NULL,
  `email` varchar(100) NOT NULL,
  `especialidad` varchar(100) DEFAULT NULL,
  `telefono` varchar(20) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

--
-- Volcado de datos para la tabla `docentes`
--

INSERT INTO `docentes` (`id_docente`, `nombre`, `apellido`, `email`, `especialidad`, `telefono`) VALUES
(1, 'Carlos', 'Perez', 'carlos.p@edutech.com', 'Base de Datos', NULL),
(2, 'Ana', 'Gomez', 'ana.g@edutech.com', 'Matemáticas', NULL),
(3, 'Luis', 'Rodriguez', 'luis.r@edutech.com', 'Programación', NULL),
(4, 'Maria', 'Lopez', 'maria.l@edutech.com', 'Gestión de Proyectos', NULL),
(5, 'Sofia', 'Mendez', 'sofia.m@edutech.com', 'Diseño UI/UX', NULL);

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `estudiantes`
--

CREATE TABLE `estudiantes` (
  `id_estudiante` int NOT NULL,
  `documento` varchar(20) NOT NULL,
  `nombre` varchar(50) NOT NULL,
  `apellido` varchar(50) NOT NULL,
  `email` varchar(100) NOT NULL,
  `fecha_nacimiento` date DEFAULT NULL,
  `id_programa` int DEFAULT NULL,
  `estado_financiero` enum('Al dia','Mora') DEFAULT 'Al dia'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

--
-- Volcado de datos para la tabla `estudiantes`
--

INSERT INTO `estudiantes` (`id_estudiante`, `documento`, `nombre`, `apellido`, `email`, `fecha_nacimiento`, `id_programa`, `estado_financiero`) VALUES
(1, '1001', 'Juan', 'Diaz', 'juan.d@mail.com', NULL, 1, 'Al dia'),
(2, '1002', 'Pedro', 'Ruiz', 'pedro.r@mail.com', NULL, 1, 'Mora'),
(3, '1003', 'Laura', 'Sanz', 'laura.s@mail.com', NULL, 3, 'Al dia'),
(4, '1004', 'Kevin', 'Mina', 'kevin.m@mail.com', NULL, 3, 'Al dia'),
(5, '1005', 'Diana', 'Paz', 'diana.p@mail.com', NULL, 2, 'Al dia'),
(6, '1006', 'Andres', 'Cruz', 'andres.c@mail.com', NULL, 1, 'Mora'),
(7, '1007', 'Camila', 'Vela', 'camila.v@mail.com', NULL, 4, 'Al dia'),
(8, '1008', 'Felipe', 'Rios', 'felipe.r@mail.com', NULL, 1, 'Al dia'),
(9, '1009', 'Natalia', 'Gil', 'natalia.g@mail.com', NULL, 5, 'Al dia'),
(10, '1010', 'Oscar', 'Luna', 'oscar.l@mail.com', NULL, 2, 'Mora'),
(11, '1011', 'Valeria', 'Sol', 'valeria.s@mail.com', NULL, 3, 'Al dia'),
(12, '1012', 'Jorge', 'Mar', 'jorge.m@mail.com', NULL, 1, 'Al dia'),
(13, '1013', 'Sara', 'Cano', 'sara.c@mail.com', NULL, 4, 'Al dia'),
(14, '1014', 'Daniel', 'Roca', 'daniel.r@mail.com', NULL, 5, 'Al dia'),
(15, '1015', 'Elena', 'Mora', 'elena.m@mail.com', NULL, 2, 'Mora'),
(16, '1016', 'Victor', 'Pena', 'victor.p@mail.com', NULL, 1, 'Al dia'),
(17, '1017', 'Gloria', 'Luz', 'gloria.l@mail.com', NULL, 3, 'Al dia'),
(18, '1018', 'Hector', 'Sal', 'hector.s@mail.com', NULL, 2, 'Al dia'),
(19, '1019', 'Irene', 'Paz', 'irene.p@mail.com', NULL, 4, 'Al dia'),
(20, '1020', 'Lucas', 'Rey', 'lucas.r@mail.com', NULL, 1, 'Al dia');

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `evaluaciones`
--

CREATE TABLE `evaluaciones` (
  `id_evaluacion` int NOT NULL,
  `id_curso` int NOT NULL,
  `nombre` varchar(50) NOT NULL,
  `porcentaje` decimal(5,2) NOT NULL
) ;

--
-- Volcado de datos para la tabla `evaluaciones`
--

INSERT INTO `evaluaciones` (`id_evaluacion`, `id_curso`, `nombre`, `porcentaje`) VALUES
(1, 1, 'Parcial 1', 30.00),
(2, 1, 'Final', 40.00),
(3, 1, 'Trabajo', 30.00),
(4, 2, 'Parcial Unico', 100.00),
(5, 6, 'Proyecto', 100.00);

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `matriculas`
--

CREATE TABLE `matriculas` (
  `id_matricula` int NOT NULL,
  `id_estudiante` int NOT NULL,
  `id_curso` int NOT NULL,
  `fecha_matricula` datetime DEFAULT CURRENT_TIMESTAMP,
  `estado` enum('Cursando','Aprobado','Reprobado','Cancelado') DEFAULT 'Cursando'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

--
-- Volcado de datos para la tabla `matriculas`
--

INSERT INTO `matriculas` (`id_matricula`, `id_estudiante`, `id_curso`, `fecha_matricula`, `estado`) VALUES
(1, 1, 1, '2025-12-23 03:34:03', 'Cursando'),
(2, 1, 2, '2025-12-23 03:34:03', 'Cursando'),
(3, 2, 1, '2025-12-23 03:34:03', 'Cursando'),
(4, 3, 5, '2025-12-23 03:34:03', 'Cursando'),
(5, 4, 5, '2025-12-23 03:34:03', 'Cursando'),
(6, 7, 6, '2025-12-23 03:34:03', 'Cursando'),
(7, 9, 7, '2025-12-23 03:34:03', 'Cursando'),
(8, 1, 8, '2025-12-23 03:34:03', 'Cursando'),
(9, 2, 2, '2025-12-23 03:34:03', 'Cursando'),
(10, 10, 4, '2025-12-23 03:34:03', 'Cursando');

--
-- Disparadores `matriculas`
--
DELIMITER $$
CREATE TRIGGER `trg_auditoria_matricula` AFTER INSERT ON `matriculas` FOR EACH ROW BEGIN
    INSERT INTO auditoria (tabla_afectada, accion, descripcion, usuario_bd)
    VALUES ('matriculas', 'INSERT', CONCAT('Estudiante ID ', NEW.id_estudiante, ' matriculado en Curso ID ', NEW.id_curso), USER());
END
$$
DELIMITER ;

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `pagos`
--

CREATE TABLE `pagos` (
  `id_pago` int NOT NULL,
  `id_estudiante` int NOT NULL,
  `id_periodo` int NOT NULL,
  `monto` decimal(10,2) NOT NULL,
  `fecha_pago` datetime DEFAULT CURRENT_TIMESTAMP,
  `metodo_pago` varchar(50) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

--
-- Volcado de datos para la tabla `pagos`
--

INSERT INTO `pagos` (`id_pago`, `id_estudiante`, `id_periodo`, `monto`, `fecha_pago`, `metodo_pago`) VALUES
(1, 1, 1, 500.00, '2025-12-23 03:34:03', 'Tarjeta'),
(2, 3, 1, 500.00, '2025-12-23 03:34:03', 'Efectivo'),
(3, 7, 1, 1200.00, '2025-12-23 03:34:03', 'Transferencia');

--
-- Disparadores `pagos`
--
DELIMITER $$
CREATE TRIGGER `trg_actualizar_financiero` AFTER INSERT ON `pagos` FOR EACH ROW BEGIN
    -- Si el estudiante hace un pago, asumimos que se pone al día (lógica simplificada)
    UPDATE estudiantes 
    SET estado_financiero = 'Al dia'
    WHERE id_estudiante = NEW.id_estudiante;
END
$$
DELIMITER ;

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `periodos_academicos`
--

CREATE TABLE `periodos_academicos` (
  `id_periodo` int NOT NULL,
  `nombre` varchar(20) NOT NULL,
  `fecha_inicio` date NOT NULL,
  `fecha_fin` date NOT NULL,
  `estado` enum('Activo','Cerrado') DEFAULT 'Activo'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

--
-- Volcado de datos para la tabla `periodos_academicos`
--

INSERT INTO `periodos_academicos` (`id_periodo`, `nombre`, `fecha_inicio`, `fecha_fin`, `estado`) VALUES
(1, '2024-1', '2024-02-01', '2024-06-30', 'Activo'),
(2, '2024-2', '2024-08-01', '2024-12-15', 'Activo');

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `programas_academicos`
--

CREATE TABLE `programas_academicos` (
  `id_programa` int NOT NULL,
  `nombre` varchar(100) NOT NULL,
  `nivel` enum('Tecnico','Tecnologico','Pregrado','Posgrado') NOT NULL,
  `duracion_semestres` int NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

--
-- Volcado de datos para la tabla `programas_academicos`
--

INSERT INTO `programas_academicos` (`id_programa`, `nombre`, `nivel`, `duracion_semestres`) VALUES
(1, 'Ingeniería de Sistemas', 'Pregrado', 10),
(2, 'Administración de Empresas', 'Pregrado', 9),
(3, 'Tecnología en Desarrollo Software', 'Tecnologico', 6),
(4, 'Maestría en Ciencia de Datos', 'Posgrado', 4),
(5, 'Diseño Gráfico', 'Pregrado', 8);

-- --------------------------------------------------------

--
-- Estructura Stand-in para la vista `vw_cursos_docentes`
-- (Véase abajo para la vista actual)
--
CREATE TABLE `vw_cursos_docentes` (
`id_curso` int
,`curso` varchar(100)
,`creditos` int
,`docente_nombre` varchar(50)
,`docente_apellido` varchar(50)
,`periodo` varchar(20)
);

-- --------------------------------------------------------

--
-- Estructura Stand-in para la vista `vw_estado_pagos`
-- (Véase abajo para la vista actual)
--
CREATE TABLE `vw_estado_pagos` (
`id_estudiante` int
,`nombre_completo` varchar(101)
,`total_pagado` decimal(32,2)
,`estado_financiero` enum('Al dia','Mora')
);

-- --------------------------------------------------------

--
-- Estructura Stand-in para la vista `vw_estudiantes_programa`
-- (Véase abajo para la vista actual)
--
CREATE TABLE `vw_estudiantes_programa` (
`id_estudiante` int
,`nombre` varchar(50)
,`apellido` varchar(50)
,`email` varchar(100)
,`programa` varchar(100)
,`nivel` enum('Tecnico','Tecnologico','Pregrado','Posgrado')
);

-- --------------------------------------------------------

--
-- Estructura Stand-in para la vista `vw_historial_academico`
-- (Véase abajo para la vista actual)
--
CREATE TABLE `vw_historial_academico` (
`documento` varchar(20)
,`estudiante` varchar(101)
,`curso` varchar(100)
,`evaluacion` varchar(50)
,`nota` decimal(3,1)
,`periodo` varchar(20)
);

--
-- Índices para tablas volcadas
--

--
-- Indices de la tabla `auditoria`
--
ALTER TABLE `auditoria`
  ADD PRIMARY KEY (`id_auditoria`);

--
-- Indices de la tabla `calificaciones`
--
ALTER TABLE `calificaciones`
  ADD PRIMARY KEY (`id_calificacion`),
  ADD UNIQUE KEY `id_matricula` (`id_matricula`,`id_evaluacion`),
  ADD KEY `id_evaluacion` (`id_evaluacion`);

--
-- Indices de la tabla `certificaciones`
--
ALTER TABLE `certificaciones`
  ADD PRIMARY KEY (`id_certificacion`),
  ADD UNIQUE KEY `codigo_verificacion` (`codigo_verificacion`),
  ADD KEY `id_estudiante` (`id_estudiante`),
  ADD KEY `id_periodo` (`id_periodo`);

--
-- Indices de la tabla `cursos`
--
ALTER TABLE `cursos`
  ADD PRIMARY KEY (`id_curso`),
  ADD KEY `id_docente` (`id_docente`),
  ADD KEY `id_programa` (`id_programa`),
  ADD KEY `id_periodo` (`id_periodo`);

--
-- Indices de la tabla `docentes`
--
ALTER TABLE `docentes`
  ADD PRIMARY KEY (`id_docente`),
  ADD UNIQUE KEY `email` (`email`);

--
-- Indices de la tabla `estudiantes`
--
ALTER TABLE `estudiantes`
  ADD PRIMARY KEY (`id_estudiante`),
  ADD UNIQUE KEY `documento` (`documento`),
  ADD UNIQUE KEY `email` (`email`),
  ADD KEY `id_programa` (`id_programa`);

--
-- Indices de la tabla `evaluaciones`
--
ALTER TABLE `evaluaciones`
  ADD PRIMARY KEY (`id_evaluacion`),
  ADD KEY `id_curso` (`id_curso`);

--
-- Indices de la tabla `matriculas`
--
ALTER TABLE `matriculas`
  ADD PRIMARY KEY (`id_matricula`),
  ADD UNIQUE KEY `id_estudiante` (`id_estudiante`,`id_curso`),
  ADD KEY `id_curso` (`id_curso`);

--
-- Indices de la tabla `pagos`
--
ALTER TABLE `pagos`
  ADD PRIMARY KEY (`id_pago`),
  ADD KEY `id_estudiante` (`id_estudiante`),
  ADD KEY `id_periodo` (`id_periodo`);

--
-- Indices de la tabla `periodos_academicos`
--
ALTER TABLE `periodos_academicos`
  ADD PRIMARY KEY (`id_periodo`);

--
-- Indices de la tabla `programas_academicos`
--
ALTER TABLE `programas_academicos`
  ADD PRIMARY KEY (`id_programa`);

--
-- AUTO_INCREMENT de las tablas volcadas
--

--
-- AUTO_INCREMENT de la tabla `auditoria`
--
ALTER TABLE `auditoria`
  MODIFY `id_auditoria` int NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=11;

--
-- AUTO_INCREMENT de la tabla `calificaciones`
--
ALTER TABLE `calificaciones`
  MODIFY `id_calificacion` int NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT de la tabla `certificaciones`
--
ALTER TABLE `certificaciones`
  MODIFY `id_certificacion` int NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT de la tabla `cursos`
--
ALTER TABLE `cursos`
  MODIFY `id_curso` int NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT de la tabla `docentes`
--
ALTER TABLE `docentes`
  MODIFY `id_docente` int NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=6;

--
-- AUTO_INCREMENT de la tabla `estudiantes`
--
ALTER TABLE `estudiantes`
  MODIFY `id_estudiante` int NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=21;

--
-- AUTO_INCREMENT de la tabla `evaluaciones`
--
ALTER TABLE `evaluaciones`
  MODIFY `id_evaluacion` int NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT de la tabla `matriculas`
--
ALTER TABLE `matriculas`
  MODIFY `id_matricula` int NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=11;

--
-- AUTO_INCREMENT de la tabla `pagos`
--
ALTER TABLE `pagos`
  MODIFY `id_pago` int NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=4;

--
-- AUTO_INCREMENT de la tabla `periodos_academicos`
--
ALTER TABLE `periodos_academicos`
  MODIFY `id_periodo` int NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=3;

--
-- AUTO_INCREMENT de la tabla `programas_academicos`
--
ALTER TABLE `programas_academicos`
  MODIFY `id_programa` int NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=6;

-- --------------------------------------------------------

--
-- Estructura para la vista `vw_cursos_docentes`
--
DROP TABLE IF EXISTS `vw_cursos_docentes`;

CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`%` SQL SECURITY DEFINER VIEW `vw_cursos_docentes`  AS SELECT `c`.`id_curso` AS `id_curso`, `c`.`nombre` AS `curso`, `c`.`creditos` AS `creditos`, `d`.`nombre` AS `docente_nombre`, `d`.`apellido` AS `docente_apellido`, `pa`.`nombre` AS `periodo` FROM ((`cursos` `c` join `docentes` `d` on((`c`.`id_docente` = `d`.`id_docente`))) join `periodos_academicos` `pa` on((`c`.`id_periodo` = `pa`.`id_periodo`))) ;

-- --------------------------------------------------------

--
-- Estructura para la vista `vw_estado_pagos`
--
DROP TABLE IF EXISTS `vw_estado_pagos`;

CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`%` SQL SECURITY DEFINER VIEW `vw_estado_pagos`  AS SELECT `e`.`id_estudiante` AS `id_estudiante`, concat(`e`.`nombre`,' ',`e`.`apellido`) AS `nombre_completo`, coalesce(sum(`p`.`monto`),0) AS `total_pagado`, `e`.`estado_financiero` AS `estado_financiero` FROM (`estudiantes` `e` left join `pagos` `p` on((`e`.`id_estudiante` = `p`.`id_estudiante`))) GROUP BY `e`.`id_estudiante`, `e`.`nombre`, `e`.`apellido`, `e`.`estado_financiero` ;

-- --------------------------------------------------------

--
-- Estructura para la vista `vw_estudiantes_programa`
--
DROP TABLE IF EXISTS `vw_estudiantes_programa`;

CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`%` SQL SECURITY DEFINER VIEW `vw_estudiantes_programa`  AS SELECT `e`.`id_estudiante` AS `id_estudiante`, `e`.`nombre` AS `nombre`, `e`.`apellido` AS `apellido`, `e`.`email` AS `email`, `p`.`nombre` AS `programa`, `p`.`nivel` AS `nivel` FROM (`estudiantes` `e` join `programas_academicos` `p` on((`e`.`id_programa` = `p`.`id_programa`))) ;

-- --------------------------------------------------------

--
-- Estructura para la vista `vw_historial_academico`
--
DROP TABLE IF EXISTS `vw_historial_academico`;

CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`%` SQL SECURITY DEFINER VIEW `vw_historial_academico`  AS SELECT `e`.`documento` AS `documento`, concat(`e`.`nombre`,' ',`e`.`apellido`) AS `estudiante`, `c`.`nombre` AS `curso`, `ev`.`nombre` AS `evaluacion`, `cal`.`nota` AS `nota`, `pa`.`nombre` AS `periodo` FROM (((((`calificaciones` `cal` join `matriculas` `m` on((`cal`.`id_matricula` = `m`.`id_matricula`))) join `estudiantes` `e` on((`m`.`id_estudiante` = `e`.`id_estudiante`))) join `evaluaciones` `ev` on((`cal`.`id_evaluacion` = `ev`.`id_evaluacion`))) join `cursos` `c` on((`m`.`id_curso` = `c`.`id_curso`))) join `periodos_academicos` `pa` on((`c`.`id_periodo` = `pa`.`id_periodo`))) ;

--
-- Restricciones para tablas volcadas
--

--
-- Filtros para la tabla `calificaciones`
--
ALTER TABLE `calificaciones`
  ADD CONSTRAINT `calificaciones_ibfk_1` FOREIGN KEY (`id_matricula`) REFERENCES `matriculas` (`id_matricula`),
  ADD CONSTRAINT `calificaciones_ibfk_2` FOREIGN KEY (`id_evaluacion`) REFERENCES `evaluaciones` (`id_evaluacion`);

--
-- Filtros para la tabla `certificaciones`
--
ALTER TABLE `certificaciones`
  ADD CONSTRAINT `certificaciones_ibfk_1` FOREIGN KEY (`id_estudiante`) REFERENCES `estudiantes` (`id_estudiante`),
  ADD CONSTRAINT `certificaciones_ibfk_2` FOREIGN KEY (`id_periodo`) REFERENCES `periodos_academicos` (`id_periodo`);

--
-- Filtros para la tabla `cursos`
--
ALTER TABLE `cursos`
  ADD CONSTRAINT `cursos_ibfk_1` FOREIGN KEY (`id_docente`) REFERENCES `docentes` (`id_docente`),
  ADD CONSTRAINT `cursos_ibfk_2` FOREIGN KEY (`id_programa`) REFERENCES `programas_academicos` (`id_programa`),
  ADD CONSTRAINT `cursos_ibfk_3` FOREIGN KEY (`id_periodo`) REFERENCES `periodos_academicos` (`id_periodo`);

--
-- Filtros para la tabla `estudiantes`
--
ALTER TABLE `estudiantes`
  ADD CONSTRAINT `estudiantes_ibfk_1` FOREIGN KEY (`id_programa`) REFERENCES `programas_academicos` (`id_programa`);

--
-- Filtros para la tabla `evaluaciones`
--
ALTER TABLE `evaluaciones`
  ADD CONSTRAINT `evaluaciones_ibfk_1` FOREIGN KEY (`id_curso`) REFERENCES `cursos` (`id_curso`);

--
-- Filtros para la tabla `matriculas`
--
ALTER TABLE `matriculas`
  ADD CONSTRAINT `matriculas_ibfk_1` FOREIGN KEY (`id_estudiante`) REFERENCES `estudiantes` (`id_estudiante`),
  ADD CONSTRAINT `matriculas_ibfk_2` FOREIGN KEY (`id_curso`) REFERENCES `cursos` (`id_curso`);

--
-- Filtros para la tabla `pagos`
--
ALTER TABLE `pagos`
  ADD CONSTRAINT `pagos_ibfk_1` FOREIGN KEY (`id_estudiante`) REFERENCES `estudiantes` (`id_estudiante`),
  ADD CONSTRAINT `pagos_ibfk_2` FOREIGN KEY (`id_periodo`) REFERENCES `periodos_academicos` (`id_periodo`);
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
