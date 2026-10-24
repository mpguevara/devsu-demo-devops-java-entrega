package devsu.devops.demo.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

import java.util.List;
import java.util.Optional;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import devsu.devops.demo.entity.User;
import devsu.devops.demo.exception.BadRequestException;
import devsu.devops.demo.exception.ResourceNotFoundException;
import devsu.devops.demo.repository.UserRepository;
import devsu.devops.demo.service.dto.UserDto;
import devsu.devops.demo.service.mapper.UserMapper;

@ExtendWith(MockitoExtension.class)
@DisplayName("User service unit tests")
class UserServiceTest {

    @InjectMocks
    private UserServiceImpl userService;

    @Mock
    private UserRepository userRepository;

    @Mock
    private UserMapper userMapper;

    @Test
    void findAllReturnsAnEmptyListWhenNoUsersExist() {
        when(userRepository.findAll()).thenReturn(List.of());

        assertThat(userService.findAll()).isEmpty();
        verifyNoInteractions(userMapper);
    }

    @Test
    void findAllMapsUsersAndPreservesRepositoryOrder() {
        User first = User.builder().id(1L).dni("0999999991").name("First User").build();
        User second = User.builder().id(2L).dni("0999999992").name("Second User").build();
        UserDto firstDto = UserDto.builder().id(1L).dni(first.getDni()).name(first.getName()).build();
        UserDto secondDto = UserDto.builder().id(2L).dni(second.getDni()).name(second.getName()).build();
        when(userRepository.findAll()).thenReturn(List.of(first, second));
        when(userMapper.toDto(first)).thenReturn(firstDto);
        when(userMapper.toDto(second)).thenReturn(secondDto);

        assertThat(userService.findAll()).containsExactly(firstDto, secondDto);
    }

    @Test
    void findByIdReturnsTheMappedUser() {
        User user = User.builder().id(1L).dni("0999999999").name("Test User").build();
        UserDto expected = UserDto.builder().id(1L).dni(user.getDni()).name(user.getName()).build();
        when(userRepository.findById(1L)).thenReturn(Optional.of(user));
        when(userMapper.toDto(user)).thenReturn(expected);

        assertThat(userService.findById(1L)).isSameAs(expected);
    }

    @Test
    void findByIdRejectsAnAbsentUser() {
        when(userRepository.findById(1L)).thenReturn(Optional.empty());

        assertThatThrownBy(() -> userService.findById(1L))
                .isInstanceOf(ResourceNotFoundException.class)
                .hasMessage("User not found: 1");
        verifyNoInteractions(userMapper);
    }

    @Test
    void saveReturnsThePersistedUserWithGeneratedId() {
        UserDto request = UserDto.builder().dni("0999999999").name("Test User").build();
        User entity = User.builder().dni(request.getDni()).name(request.getName()).build();
        User saved = User.builder().id(7L).dni(request.getDni()).name(request.getName()).build();
        UserDto expected = UserDto.builder().id(7L).dni(request.getDni()).name(request.getName()).build();
        when(userRepository.existsByDni(request.getDni())).thenReturn(false);
        when(userMapper.toEntity(request)).thenReturn(entity);
        when(userRepository.save(entity)).thenReturn(saved);
        when(userMapper.toDto(saved)).thenReturn(expected);

        assertThat(userService.save(request)).isSameAs(expected);
    }

    @Test
    void saveRejectsADuplicateDniBeforeWriting() {
        UserDto request = UserDto.builder().dni("0999999999").name("Test User").build();
        when(userRepository.existsByDni(request.getDni())).thenReturn(true);

        assertThatThrownBy(() -> userService.save(request))
                .isInstanceOf(BadRequestException.class)
                .hasMessage("User already exists");
        verify(userRepository, never()).save(any(User.class));
        verifyNoInteractions(userMapper);
    }
}
