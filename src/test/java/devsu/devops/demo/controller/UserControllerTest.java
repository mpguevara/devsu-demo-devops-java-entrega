package devsu.devops.demo.controller;

import static org.assertj.core.api.Assertions.assertThat;
import static org.hamcrest.Matchers.hasSize;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import tools.jackson.databind.JsonNode;
import tools.jackson.databind.ObjectMapper;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.transaction.annotation.Transactional;

@AutoConfigureMockMvc
@SpringBootTest
@ActiveProfiles("test")
@Transactional
@DisplayName("User HTTP contract with isolated H2 transactions")
class UserControllerTest {

    private static final String VALID_USER = "{\"dni\":\"9999999901\",\"name\":\"Prueba DevOps\"}";

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private ObjectMapper objectMapper;

    @Test
    void listsUsersAsAJsonArray() throws Exception {
        mockMvc.perform(get("/users"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$").isArray());
    }

    @Test
    void createsAndRetrievesAUserWithAServerGeneratedId() throws Exception {
        String requestWithClientId = """
                {"id":2147483647,"dni":"9999999901","name":"Prueba DevOps"}
                """;
        String body = mockMvc.perform(post("/users").contentType(MediaType.APPLICATION_JSON).content(requestWithClientId))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.dni").value("9999999901"))
                .andExpect(jsonPath("$.name").value("Prueba DevOps"))
                .andReturn().getResponse().getContentAsString();
        JsonNode user = objectMapper.readTree(body);
        assertThat(user.path("id").asLong()).isPositive().isNotEqualTo(2147483647L);

        mockMvc.perform(get("/users/{id}", user.path("id").asLong()))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.id").value(user.path("id").asInt()))
                .andExpect(jsonPath("$.dni").value("9999999901"))
                .andExpect(jsonPath("$.name").value("Prueba DevOps"));
    }

    @Test
    void duplicateDniReturns400AndDoesNotCreateAnotherUser() throws Exception {
        mockMvc.perform(post("/users").contentType(MediaType.APPLICATION_JSON).content(VALID_USER))
                .andExpect(status().isCreated());

        mockMvc.perform(post("/users").contentType(MediaType.APPLICATION_JSON).content(VALID_USER))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.errors[0]").value("User already exists"));
        mockMvc.perform(get("/users"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$", hasSize(1)));
    }

    @ParameterizedTest
    @ValueSource(strings = {
            "{\"dni\":\"\",\"name\":\"\"}",
            "{\"dni\":\"123\",\"name\":\"Prueba DevOps\"}",
            "{\"dni\":\"9999999901\",\"name\":\"Abcd\"}"
    })
    void rejectsInvalidUsersWithoutPersistingThem(String body) throws Exception {
        mockMvc.perform(post("/users").contentType(MediaType.APPLICATION_JSON).content(body))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.errors").isNotEmpty());
        mockMvc.perform(get("/users"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$", hasSize(0)));
    }

    @Test
    void returns404ForAnAbsentUser() throws Exception {
        mockMvc.perform(get("/users/{id}", Long.MAX_VALUE))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.errors[0]").value("User not found: " + Long.MAX_VALUE));
    }

    @Test
    void returns400ForANonNumericUserId() throws Exception {
        mockMvc.perform(get("/users/not-a-number"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.errors").isArray());
    }

    @Test
    void returns415ForAnUnsupportedContentType() throws Exception {
        mockMvc.perform(post("/users").contentType(MediaType.TEXT_PLAIN).content(VALID_USER))
                .andExpect(status().isUnsupportedMediaType());
    }
}
